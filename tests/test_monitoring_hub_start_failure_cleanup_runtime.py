"""Runtime probe for MonitoringHub startup failure cleanup."""

import tempfile
import unittest
from unittest.mock import patch

from parsl.monitoring.monitoring import MonitoringHub


class _FakeQueue:
    def close(self):
        pass

    def join_thread(self):
        pass


class _FakeEvent:
    def set(self):
        pass


class _FailingProcess:
    def __init__(self, *args, **kwargs):
        pass

    def start(self):
        raise RuntimeError("child process could not start")


class MonitoringHubStartFailureCleanupRuntimeTest(unittest.TestCase):
    def test_process_start_failure_leaves_hub_active_currently(self):
        hub = MonitoringHub.__new__(MonitoringHub)
        hub.logging_endpoint = "sqlite:///unused.db"
        hub.monitoring_debug = False

        with tempfile.TemporaryDirectory() as run_dir, patch(
            "parsl.monitoring.monitoring.SpawnQueue", return_value=_FakeQueue()
        ), patch(
            "parsl.monitoring.monitoring.SpawnEvent", return_value=_FakeEvent()
        ), patch(
            "parsl.monitoring.monitoring.SpawnProcess", _FailingProcess
        ):
            with self.assertRaises(RuntimeError):
                hub.start(run_dir, run_dir, None)

        self.assertTrue(hub.monitoring_hub_active)
        self.assertIsInstance(hub.resource_msgs, _FakeQueue)
        self.assertIsInstance(hub.dbm_proc, _FailingProcess)


if __name__ == "__main__":
    unittest.main()

