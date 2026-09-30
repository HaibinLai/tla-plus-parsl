"""Runtime probe for HTEX idle-only negative scale-in handling."""

import unittest

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.jobs.states import JobState, JobStatus


class FakeProvider:
    def __init__(self):
        self.calls = []

    def cancel(self, job_ids):
        self.calls.append(list(job_ids))
        return [True for _ in job_ids]


class HtexNegativeScaleInRuntimeTest(unittest.TestCase):
    def test_negative_idle_scale_in_selects_all_idle_blocks_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
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
        held = []
        executor._hold_block = held.append
        executor.connected_managers = lambda: [
            {"active": True, "block_id": f"block-{i}", "tasks": 0, "idle_duration": 10}
            for i in range(3)
        ]

        executor.scale_in(-1, max_idletime=0)

        self.assertEqual(held, ["block-0", "block-1", "block-2"])
        self.assertEqual(executor._provider.calls, [["job-0", "job-1", "job-2"]])

    def test_zero_idle_scale_in_selects_all_idle_blocks_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
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
        held = []
        executor._hold_block = held.append
        executor.connected_managers = lambda: [
            {"active": True, "block_id": f"block-{i}", "tasks": 0, "idle_duration": 10}
            for i in range(3)
        ]

        executor.scale_in(0, max_idletime=0)

        self.assertEqual(held, ["block-0", "block-1", "block-2"])
        self.assertEqual(executor._provider.calls, [["job-0", "job-1", "job-2"]])


if __name__ == "__main__":
    unittest.main()
