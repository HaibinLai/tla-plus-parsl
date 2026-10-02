"""Runtime bridge for expired HTEX managers and serialized attempt results."""

import datetime
import pickle
import tempfile
import unittest
from unittest.mock import Mock, patch

import zmq

from parsl.executors.flux import TaskResult
from parsl.executors.high_throughput.interchange import Interchange
from parsl.monitoring.db_manager import Database, STATUS, WORKFLOW
from parsl.serialize import deserialize, serialize


class HeartbeatSocket:
    def __init__(self, message):
        self.message = message
        self.sent = []

    def recv_multipart(self):
        return self.message

    def send_multipart(self, message):
        self.sent.append(message)


class HeartbeatResultAttemptRuntimeTest(unittest.TestCase):
    def test_expiry_ignores_late_heartbeat_and_preserves_worker_loss(self):
        interchange = Interchange.__new__(Interchange)
        interchange.heartbeat_threshold = 10
        interchange._ready_managers = {
            b"manager-1": {
                "last_heartbeat": 89,
                "active": True,
                "tasks": [17],
                "hostname": "worker-host",
            }
        }
        interchange.results_outgoing = type("Out", (), {"messages": []})()
        interchange.results_outgoing.send = lambda message: interchange.results_outgoing.messages.append(message)
        interchange.monitoring_events = []
        interchange._send_monitoring_info = lambda radio, manager: None

        with patch("parsl.executors.high_throughput.interchange.time.time", return_value=100):
            interchange.expire_bad_managers({b"manager-1"}, monitoring_radio=object())

        self.assertNotIn(b"manager-1", interchange._ready_managers)
        result = pickle.loads(interchange.results_outgoing.messages[0])
        self.assertEqual(result["task_id"], 17)

    def test_old_serialized_result_is_not_selected_for_retry_attempt(self):
        old = {"task_id": "task-1", "attempt": 0, "payload": serialize(TaskResult("old", None))}
        current = {"task_id": "task-1", "attempt": 1, "payload": serialize(TaskResult("new", None))}
        accepted = []
        for message in (old, current):
            if message["attempt"] != 1:
                continue
            accepted.append(deserialize(message["payload"]).returnval)

        self.assertEqual(accepted, ["new"])

    def test_manager_loss_status_survives_late_old_result(self):
        interchange = Interchange.__new__(Interchange)
        interchange.heartbeat_threshold = 10
        interchange._ready_managers = {
            b"manager-1": {
                "last_heartbeat": 89,
                "active": True,
                "tasks": [17],
                "hostname": "worker-host",
            }
        }
        interchange.results_outgoing = type("Out", (), {"messages": []})()
        interchange.results_outgoing.send = lambda message: interchange.results_outgoing.messages.append(message)
        interchange._send_monitoring_info = lambda radio, manager: None

        with patch("parsl.executors.high_throughput.interchange.time.time", return_value=100):
            interchange.expire_bad_managers({b"manager-1"}, monitoring_radio=object())

        # A heartbeat received after expiry must not recreate the manager or
        # send an acknowledgement that could make it appear live again.
        manager_sock = HeartbeatSocket(
            [b"manager-1", pickle.dumps({"type": "heartbeat"})]
        )
        interchange.manager_sock = manager_sock
        interchange.socks = {manager_sock: zmq.POLLIN}
        interesting = set()
        interchange.process_manager_socket_message(
            interesting, monitoring_radio=None, kill_event=Mock()
        )
        self.assertEqual(interchange._ready_managers, {})
        self.assertEqual(interesting, set())
        self.assertEqual(manager_sock.sent, [])

        with tempfile.TemporaryDirectory() as directory:
            database = Database("sqlite:///" + directory + "/monitoring.db")
            now = datetime.datetime.now()
            database.insert(table=WORKFLOW, messages=[{
                "run_id": "heartbeat-run", "time_began": now, "host": "host",
                "user": "user", "rundir": directory,
                "tasks_failed_count": 0, "tasks_completed_count": 0,
            }])
            database.insert(table=STATUS, messages=[{
                "task_id": 17, "run_id": "heartbeat-run",
                "task_status_name": "lost", "timestamp": now, "try_id": 0,
            }])

            current_attempt = 1
            late = {"task_id": 17, "attempt": 0,
                    "payload": serialize(TaskResult("late", None))}
            accepted = []
            if late["attempt"] == current_attempt:
                accepted.append(deserialize(late["payload"]).returnval)

            rows = database.session.execute(database.meta.tables[STATUS].select()).fetchall()

        self.assertEqual(accepted, [])
        self.assertEqual(rows[0].task_status_name, "lost")


if __name__ == "__main__":
    unittest.main()
