"""Runtime probes for the HTEX manager heartbeat expiry boundary."""

import pickle
import unittest
from unittest.mock import Mock, patch

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class FakeOutgoing:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class FakeManagerSocket:
    def __init__(self, message):
        self.message = message
        self.sent = []

    def recv_multipart(self):
        return self.message

    def send_multipart(self, message):
        self.sent.append(message)


class HtexHeartbeatRuntimeTest(unittest.TestCase):
    def make_interchange(self, last_heartbeat):
        interchange = Interchange.__new__(Interchange)
        interchange.heartbeat_threshold = 10
        interchange._ready_managers = {
            b"manager-1": {
                "last_heartbeat": last_heartbeat,
                "active": True,
                "tasks": [17],
                "hostname": "worker-host",
            }
        }
        interchange.results_outgoing = FakeOutgoing()
        interchange.monitoring_events = []
        interchange._send_monitoring_info = (
            lambda radio, manager: interchange.monitoring_events.append(manager["active"])
        )
        return interchange

    def test_threshold_is_strict_and_boundary_does_not_expire(self):
        interchange = self.make_interchange(last_heartbeat=90)
        interesting = {b"manager-1"}

        with patch("parsl.executors.high_throughput.interchange.time.time", return_value=100):
            interchange.expire_bad_managers(interesting, monitoring_radio=object())

        self.assertIn(b"manager-1", interchange._ready_managers)
        self.assertEqual(interchange.results_outgoing.messages, [])

    def test_expiry_deactivates_manager_and_reports_inflight_task(self):
        interchange = self.make_interchange(last_heartbeat=89)
        interesting = {b"manager-1"}

        with patch("parsl.executors.high_throughput.interchange.time.time", return_value=100):
            interchange.expire_bad_managers(interesting, monitoring_radio=object())

        self.assertNotIn(b"manager-1", interchange._ready_managers)
        self.assertNotIn(b"manager-1", interesting)
        self.assertEqual(interchange.monitoring_events, [False])
        self.assertEqual(len(interchange.results_outgoing.messages), 1)
        result = pickle.loads(interchange.results_outgoing.messages[0])
        self.assertEqual(result["type"], "result")
        self.assertEqual(result["task_id"], 17)

    def test_late_heartbeat_from_expired_manager_is_ignored(self):
        interchange = Interchange.__new__(Interchange)
        manager_id = b"expired-manager"
        interchange._ready_managers = {}
        interchange.manager_sock = FakeManagerSocket(
            [manager_id, pickle.dumps({"type": "heartbeat"})]
        )
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interesting = set()

        interchange.process_manager_socket_message(
            interesting,
            monitoring_radio=None,
            kill_event=Mock(),
        )

        self.assertEqual(interchange._ready_managers, {})
        self.assertEqual(interesting, set())
        self.assertEqual(interchange.manager_sock.sent, [])


if __name__ == "__main__":
    unittest.main()
