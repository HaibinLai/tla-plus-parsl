"""Runtime probe for negative BlockProviderExecutor.scale_in requests."""

import unittest

from parsl.executors.status_handling import BlockProviderExecutor
from parsl.jobs.states import JobState, JobStatus


class FakeProvider:
    def __init__(self):
        self.calls = []

    def cancel(self, job_ids):
        self.calls.append(list(job_ids))
        return [True for _ in job_ids]


class ConcreteBlockExecutor(BlockProviderExecutor):
    def outstanding(self):
        return 0

    @property
    def workers_per_node(self):
        return 1

    def _get_launch_command(self, block_id):
        return ""

    def submit(self, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self):
        pass


class NegativeScaleInRuntimeTest(unittest.TestCase):
    def test_negative_scale_in_cancels_all_but_last_block_currently(self):
        executor = ConcreteBlockExecutor.__new__(ConcreteBlockExecutor)
        executor._status = {
            f"block-{i}": JobStatus(JobState.RUNNING) for i in range(3)
        }
        executor.blocks_to_job_id = {
            f"block-{i}": f"job-{i}" for i in range(3)
        }
        executor.job_ids_to_block = {
            f"job-{i}": f"block-{i}" for i in range(3)
        }
        executor._provider = FakeProvider()

        cancelled = executor.scale_in(-1)

        self.assertEqual(cancelled, ["block-0", "block-1"])
        self.assertEqual(executor._provider.calls, [["job-0", "job-1"]])


if __name__ == "__main__":
    unittest.main()
