"""Runtime probe for HTEX heartbeat expiry based on adjustable wall time."""

import unittest
from unittest.mock import patch

from parsl.executors.high_throughput.interchange import Interchange


class HeartbeatClockJumpRuntimeTest(unittest.TestCase):
    def test_forward_wall_clock_jump_expires_manager_currently(self):
        interchange = Interchange.__new__(Interchange)
        interchange.heartbeat_threshold = 10
        interchange._ready_managers = {
            b"manager-1": {
                "last_heartbeat": 100,
                "active": True,
                "tasks": [],
                "hostname": "worker-host",
            }
        }
        interchange._send_monitoring_info = lambda radio, manager: None
        interesting = {b"manager-1"}

        with patch("parsl.executors.high_throughput.interchange.time.time", return_value=1000):
            interchange.expire_bad_managers(interesting, monitoring_radio=object())

        self.assertNotIn(b"manager-1", interchange._ready_managers)
        self.assertNotIn(b"manager-1", interesting)

    def test_backward_wall_clock_jump_delays_expiry_currently(self):
        interchange = Interchange.__new__(Interchange)
        interchange.heartbeat_threshold = 10
        interchange._ready_managers = {
            b"manager-1": {
                "last_heartbeat": 100,
                "active": True,
                "tasks": [],
                "hostname": "worker-host",
            }
        }
        interchange._send_monitoring_info = lambda radio, manager: None
        interesting = {b"manager-1"}

        # A backward wall-clock step makes the current age negative.
        with patch("parsl.executors.high_throughput.interchange.time.time", return_value=90):
            interchange.expire_bad_managers(interesting, monitoring_radio=object())

        self.assertIn(b"manager-1", interchange._ready_managers)
        self.assertIn(b"manager-1", interesting)


if __name__ == "__main__":
    unittest.main()
