"""Runtime probe for provider-status failure isolation across executors."""

import unittest

from parsl.jobs.job_status_poller import JobStatusPoller


class FailingExecutor:
    def __init__(self, name, calls):
        self.name = name
        self.calls = calls

    def poll_facade(self):
        self.calls.append(self.name)
        raise RuntimeError("provider status failed")

    def handle_errors(self, _status):
        raise AssertionError("current poll must fail before handle_errors")


class HealthyExecutor:
    def __init__(self, calls):
        self.calls = calls

    def poll_facade(self):
        self.calls.append("healthy")

    def handle_errors(self, _status):
        self.calls.append("healthy-errors")


class PollerExecutorIsolationRuntimeTest(unittest.TestCase):
    def test_first_provider_failure_skips_later_executor_currently(self):
        calls = []
        poller = JobStatusPoller.__new__(JobStatusPoller)
        poller._executors = [FailingExecutor("failing", calls), HealthyExecutor(calls)]

        with self.assertRaises(RuntimeError):
            poller.poll()

        self.assertEqual(calls, ["failing"])


if __name__ == "__main__":
    unittest.main()
