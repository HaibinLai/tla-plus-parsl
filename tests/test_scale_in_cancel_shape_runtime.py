"""Runtime probe for malformed provider.cancel result cardinality."""

import unittest

from parsl.executors.status_handling import BlockProviderExecutor
from parsl.jobs.states import JobState, JobStatus


class ShortCancelProvider:
    status_polling_interval = 1

    def cancel(self, job_ids):
        return [True]


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


class ScaleInCancelShapeRuntimeTest(unittest.TestCase):
    def test_short_cancel_result_raises_shape_assertion_currently(self):
        executor = ProbeExecutor(ShortCancelProvider())
        executor._status = {
            "block-0": JobStatus(JobState.RUNNING),
            "block-1": JobStatus(JobState.RUNNING),
        }
        executor.blocks_to_job_id = {"block-0": "job-0", "block-1": "job-1"}
        executor.job_ids_to_block = {"job-0": "block-0", "job-1": "block-1"}

        with self.assertRaises(AssertionError):
            executor.scale_in(2)


if __name__ == "__main__":
    unittest.main()
