"""Runtime probe for repeated MonitoringHub.start calls."""

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


class _FakeProcess:
    instances = []

    def __init__(self, *args, **kwargs):
        self.started = False
        self.closed = False
        self.pid = len(self.__class__.instances) + 1
        self.__class__.instances.append(self)

    def start(self):
        self.started = True


class MonitoringHubRepeatedStartRuntimeTest(unittest.TestCase):
    def test_repeated_start_overwrites_first_process_currently(self):
        _FakeProcess.instances = []
        hub = MonitoringHub.__new__(MonitoringHub)
        hub.logging_endpoint = "sqlite:///unused.db"
        hub.monitoring_debug = False

        with tempfile.TemporaryDirectory() as run_dir, patch(
            "parsl.monitoring.monitoring.SpawnQueue", return_value=_FakeQueue()
        ), patch(
            "parsl.monitoring.monitoring.SpawnEvent", return_value=_FakeEvent()
        ), patch(
            "parsl.monitoring.monitoring.SpawnProcess", _FakeProcess
        ):
            hub.start(run_dir, run_dir, None)
            first_process = hub.dbm_proc
            hub.start(run_dir, run_dir, None)
            second_process = hub.dbm_proc

        self.assertEqual(len(_FakeProcess.instances), 2)
        self.assertIsNot(first_process, second_process)
        self.assertTrue(hub.monitoring_hub_active)
        self.assertTrue(first_process.started)


if __name__ == "__main__":
    unittest.main()
