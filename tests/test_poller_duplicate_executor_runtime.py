"""Runtime probe for duplicate JobStatusPoller executor registration."""

import unittest

from parsl.jobs.job_status_poller import JobStatusPoller


class StrategyDouble:
    def __init__(self):
        self.calls = []

    def add_executors(self, executors):
        self.calls.append(list(executors))


class ExecutorDouble:
    label = "duplicate-test"
    status_polling_interval = 1
    provider = object()


class PollerDuplicateExecutorRuntimeTest(unittest.TestCase):
    def test_repeated_registration_appends_same_executor_currently(self):
        poller = JobStatusPoller.__new__(JobStatusPoller)
        poller._executors = []
        poller._strategy = StrategyDouble()
        executor = ExecutorDouble()

        poller.add_executors([executor])
        poller.add_executors([executor])

        self.assertEqual(poller._executors, [executor, executor])
        self.assertEqual(poller._strategy.calls, [[executor], [executor]])


if __name__ == "__main__":
    unittest.main()
