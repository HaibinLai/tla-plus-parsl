"""Runtime probe for HTEX forced scale-in of a busy block."""

import unittest

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.jobs.states import JobState, JobStatus


class FakeProvider:
    def __init__(self):
        self.cancelled = []

    def cancel(self, job_ids):
        self.cancelled.append(list(job_ids))
        return [True for _ in job_ids]


class HtexForceScaleInRuntimeTest(unittest.TestCase):
    def _executor(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor._status = {"block-1": JobStatus(JobState.RUNNING)}
        executor.blocks_to_job_id = {"block-1": "job-1"}
        executor.job_ids_to_block = {"job-1": "block-1"}
        executor._provider = FakeProvider()
        held = []
        executor._hold_block = held.append
        executor.connected_managers = lambda: [{
            "active": True,
            "block_id": "block-1",
            "tasks": 1,
            "idle_duration": 0.0,
        }]
        executor._filter_scale_in_ids = lambda job_ids, results: job_ids
        return executor, held

    def test_default_scale_in_cancels_busy_block(self):
        executor, held = self._executor()

        self.assertEqual(executor.scale_in(1), ["block-1"])
        self.assertEqual(held, ["block-1"])
        self.assertEqual(executor.provider.cancelled, [["job-1"]])

    def test_idle_threshold_protects_busy_block(self):
        executor, held = self._executor()

        self.assertEqual(executor.scale_in(1, max_idletime=0), [])
        self.assertEqual(held, [])
        self.assertEqual(executor.provider.cancelled, [[]])


if __name__ == "__main__":
    unittest.main()
