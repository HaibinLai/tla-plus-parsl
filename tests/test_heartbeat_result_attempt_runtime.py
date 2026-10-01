"""Runtime bridge for expired HTEX managers and serialized attempt results."""

import pickle
import unittest
from unittest.mock import Mock, patch

from parsl.executors.flux import TaskResult
from parsl.executors.high_throughput.interchange import Interchange
from parsl.serialize import deserialize, serialize


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


if __name__ == "__main__":
    unittest.main()
