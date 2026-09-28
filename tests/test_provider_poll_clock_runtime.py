"""Probe provider polling after a wall-clock rollback."""

import unittest
from unittest.mock import patch

from parsl.executors.status_handling import BlockProviderExecutor
from parsl.jobs.states import JobState, JobStatus


class FakeProvider:
    status_polling_interval = 10

    def __init__(self):
        self.calls = 0

    def status(self, job_ids):
        self.calls += 1
        return [JobStatus(JobState.RUNNING) for _ in job_ids]


class ProbeExecutor(BlockProviderExecutor):
    def __init__(self, provider):
        super().__init__(provider=provider, block_error_handler=False)
        self.label = "probe"

    def submit(self, func, resource_specification, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self):
        pass

    def outstanding(self):
        return 0

    @property
    def workers_per_node(self):
        return 1

    def _get_launch_command(self, block_id):
        return "true"


class ProviderPollClockRuntimeTest(unittest.TestCase):
    def test_wall_clock_rollback_suppresses_poll_currently(self):
        provider = FakeProvider()
        executor = ProbeExecutor(provider)
        executor.blocks_to_job_id = {"b": "j"}
        executor.job_ids_to_block = {"j": "b"}
        executor._status = {"b": JobStatus(JobState.PENDING)}
        executor._last_poll_time = 100

        with patch("parsl.executors.status_handling.time.time", return_value=90):
            executor.poll_facade()

        self.assertEqual(provider.calls, 0)
        self.assertEqual(executor.status_facade["b"].state, JobState.PENDING)

    def test_forward_elapsed_time_polls_normally(self):
        provider = FakeProvider()
        executor = ProbeExecutor(provider)
        executor.blocks_to_job_id = {"b": "j"}
        executor.job_ids_to_block = {"j": "b"}
        executor._status = {"b": JobStatus(JobState.PENDING)}
        executor._last_poll_time = 100

        with patch("parsl.executors.status_handling.time.time", return_value=111):
            executor.poll_facade()

        self.assertEqual(provider.calls, 1)
        self.assertEqual(executor.status_facade["b"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
