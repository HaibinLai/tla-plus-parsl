"""Runtime probe for concurrent HTEX scale-in selection."""

import threading
import unittest

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.jobs.states import JobState, JobStatus


class RacingProvider:
    def __init__(self):
        self.calls = []
        self.barrier = threading.Barrier(2)

    def cancel(self, job_ids):
        self.barrier.wait(timeout=2)
        self.calls.append(list(job_ids))
        return [True for _ in job_ids]


class HtexScaleInRaceRuntimeTest(unittest.TestCase):
    def test_concurrent_scale_in_sends_duplicate_cancel_requests_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor._status = {"block-1": JobStatus(JobState.RUNNING)}
        executor.blocks_to_job_id = {"block-1": "job-1"}
        executor.job_ids_to_block = {"job-1": "block-1"}
        executor._provider = RacingProvider()
        executor._hold_block = lambda block_id: None
        executor.connected_managers = lambda: [
            {"active": True, "block_id": "block-1", "tasks": 0, "idle_duration": 10}
        ]

        errors = []

        def call_scale_in():
            try:
                executor.scale_in(1)
            except Exception as exc:  # pragma: no cover - diagnostic path
                errors.append(exc)

        first = threading.Thread(target=call_scale_in)
        second = threading.Thread(target=call_scale_in)
        first.start()
        second.start()
        first.join(timeout=3)
        second.join(timeout=3)

        self.assertEqual(errors, [])
        self.assertEqual(executor._provider.calls, [["job-1"], ["job-1"]])


if __name__ == "__main__":
    unittest.main()
