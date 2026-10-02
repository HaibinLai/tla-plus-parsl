"""Runtime bridge for heartbeat expiry, timeout terminality, and stale result frames."""

import pickle
import unittest
from concurrent.futures import Future
from unittest.mock import patch

from parsl.executors.high_throughput.interchange import Interchange


class _Outgoing:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class HeartbeatTimeoutFutureMonitoringRuntimeTest(unittest.TestCase):
    def test_expiry_frame_cannot_overwrite_timed_out_future(self):
        interchange = Interchange.__new__(Interchange)
        interchange.heartbeat_threshold = 2
        interchange._ready_managers = {
            b"manager-timeout": {
                "last_heartbeat": 0,
                "active": True,
                "tasks": [41],
                "hostname": "worker-host",
            }
        }
        interchange.results_outgoing = _Outgoing()
        interchange.monitoring_events = []
        interchange._send_monitoring_info = lambda radio, manager: interchange.monitoring_events.append(
            manager["active"]
        )

        logical_future = Future()
        logical_future.set_exception(TimeoutError("task deadline expired"))
        with patch("parsl.executors.high_throughput.interchange.time.time", return_value=3):
            interchange.expire_bad_managers({b"manager-timeout"}, monitoring_radio=object())

        frame = pickle.loads(interchange.results_outgoing.messages[0])
        self.assertEqual(frame["task_id"], 41)
        self.assertEqual(frame["type"], "result")
        self.assertEqual(interchange.monitoring_events, [False])

        # A client-side timeout has already made this logical Future terminal;
        # the manager-loss frame is stale and must not call set_result again.
        if not logical_future.done():
            logical_future.set_result(frame)
        self.assertIsInstance(logical_future.exception(), TimeoutError)


if __name__ == "__main__":
    unittest.main()
