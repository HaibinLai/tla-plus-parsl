"""Runtime probe for provider polling after a wall-clock rollback."""

import unittest
from unittest.mock import patch

from parsl.executors.status_handling import BlockProviderExecutor
from parsl.jobs.states import JobState, JobStatus


class FakeProvider:
    status_polling_interval = 10


class ProbeExecutor(BlockProviderExecutor):
    def _get_launch_command(self, *args, **kwargs):
        return ""

    @property
    def outstanding(self):
        return 0

    @property
    def workers_per_node(self):
        return 1

    def submit(self, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self, *args, **kwargs):
        return None


class PollClockRollbackRuntimeTest(unittest.TestCase):
    def test_backward_wall_clock_jump_suppresses_due_poll_currently(self):
        executor = ProbeExecutor.__new__(ProbeExecutor)
        executor._provider = FakeProvider()
        executor._last_poll_time = 100.0
        executor._status = {}
        calls = []
        executor.status = lambda: calls.append("polled") or {
            "block": JobStatus(JobState.RUNNING)
        }
        executor.send_monitoring_info = lambda status: None

        with patch("parsl.executors.status_handling.time.time", return_value=90.0):
            executor.poll_facade()

        self.assertEqual(calls, [])
        self.assertEqual(executor._last_poll_time, 100.0)


if __name__ == "__main__":
    unittest.main()
