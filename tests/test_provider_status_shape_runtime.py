"""Runtime probe for a short provider.status response."""

import unittest

from parsl.executors.status_handling import BlockProviderExecutor
from parsl.jobs.states import JobState, JobStatus


class ShortStatusProvider:
    status_polling_interval = 1

    def status(self, job_ids):
        return [JobStatus(JobState.RUNNING)]


class ProbeExecutor(BlockProviderExecutor):
    def __init__(self, provider):
        super().__init__(provider=provider, block_error_handler=False)

    def outstanding(self):
        return 0

    @property
    def workers_per_node(self):
        return 1

    def _get_launch_command(self, block_id):
        return "true"

    def submit(self, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self, *args, **kwargs):
        return None


class ProviderStatusShapeRuntimeTest(unittest.TestCase):
    def test_short_status_response_raises_index_error_currently(self):
        executor = ProbeExecutor(ShortStatusProvider())
        executor.blocks_to_job_id = {"block-0": "job-0", "block-1": "job-1"}
        executor.job_ids_to_block = {"job-0": "block-0", "job-1": "block-1"}

        with self.assertRaises(IndexError):
            executor.status()


if __name__ == "__main__":
    unittest.main()
