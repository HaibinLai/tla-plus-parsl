"""Runtime bridge from provider poll isolation to independent Futures."""

import unittest
from concurrent.futures import Future

from parsl.jobs.job_status_poller import JobStatusPoller


class _FailingExecutor:
    def __init__(self, calls):
        self.calls = calls

    def poll_facade(self):
        self.calls.append("failing")
        raise RuntimeError("provider status failed")


class _HealthyExecutor:
    def __init__(self, calls, future):
        self.calls = calls
        self.future = future

    def poll_facade(self):
        self.calls.append("healthy")
        self.future.set_result("healthy-result")


class PollerExecutorFutureIsolationRuntimeTest(unittest.TestCase):
    def test_provider_poll_failure_strands_independent_future_currently(self):
        calls = []
        healthy_future = Future()
        poller = JobStatusPoller.__new__(JobStatusPoller)
        poller._executors = [
            _FailingExecutor(calls),
            _HealthyExecutor(calls, healthy_future),
        ]

        with self.assertRaises(RuntimeError):
            poller.poll()

        self.assertEqual(calls, ["failing"])
        self.assertFalse(healthy_future.done())


if __name__ == "__main__":
    unittest.main()
