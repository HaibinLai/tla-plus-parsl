"""Runtime bridge for manager-loss synthetic-result send failure."""

import unittest
from unittest.mock import patch

from parsl.executors.high_throughput.interchange import Interchange


class FailingOutgoing:
    def send(self, _message):
        raise OSError("simulated result transport failure")


class HtexManagerLossSendFailureRuntimeTest(unittest.TestCase):
    def test_manager_loss_send_failure_leaves_manager_and_task_currently(self):
        interchange = Interchange.__new__(Interchange)
        interchange.heartbeat_threshold = 1
        interchange._ready_managers = {
            b"manager-1": {
                "last_heartbeat": 0,
                "active": True,
                "tasks": [17],
                "hostname": "host",
            }
        }
        interchange.results_outgoing = FailingOutgoing()

        with patch("parsl.executors.high_throughput.interchange.time.time", return_value=10):
            with self.assertRaises(OSError):
                interchange.expire_bad_managers(set(), monitoring_radio=None)

        self.assertIn(b"manager-1", interchange._ready_managers)
        self.assertEqual(interchange._ready_managers[b"manager-1"]["tasks"], [17])


if __name__ == "__main__":
    unittest.main()
