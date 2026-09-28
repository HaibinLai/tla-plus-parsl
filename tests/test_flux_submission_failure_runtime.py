"""Runtime probe for Flux submission-queue failure cleanup."""

import queue
import unittest
from concurrent.futures import Future

from parsl.executors.flux.executor import _error_out_jobs


class JobInfo:
    def __init__(self):
        self.future = Future()


class OneJobQueue:
    def __init__(self, job):
        self.job = job
        self.used = False

    def empty(self):
        return self.used

    def get(self, timeout=None):
        if not self.used:
            self.used = True
            return self.job
        raise queue.Empty


class StopFlag:
    is_set = lambda self: True


class FluxSubmissionFailureRuntimeTest(unittest.TestCase):
    def test_error_out_jobs_fails_queued_future_after_stop(self):
        job = JobInfo()

        _error_out_jobs(OneJobQueue(job), StopFlag(), RuntimeError("submit failed"))

        with self.assertRaises(RuntimeError):
            job.future.result()


if __name__ == "__main__":
    unittest.main()
