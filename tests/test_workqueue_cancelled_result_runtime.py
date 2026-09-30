"""Runtime probe for WorkQueue result delivery after Future cancellation."""

import multiprocessing
import queue
import threading
import unittest
from concurrent.futures import Future, InvalidStateError

from parsl.executors.workqueue.executor import WorkQueueExecutor, WqTaskToParsl


class TwoReportQueue:
    def __init__(self, reports, stop):
        self.reports = list(reports)
        self.stop = stop

    def get(self, timeout=None):
        if self.reports:
            report = self.reports.pop(0)
            if not self.reports:
                self.stop.value = True
            return report
        raise queue.Empty


class WorkQueueCancelledResultRuntimeTest(unittest.TestCase):
    def test_cancelled_result_terminates_current_collector_and_fails_later_task(self):
        stop = multiprocessing.Value("b", False)
        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
        executor.should_stop = stop
        executor.submit_process = type("Alive", (), {"is_alive": lambda self: True})()
        executor.tasks_lock = threading.Lock()
        first = Future()
        self.assertTrue(first.cancel())
        second = Future()
        first_report = WqTaskToParsl("first", True, "/unused-first", None, None)
        second_report = WqTaskToParsl("second", True, "/unused-second", None, None)
        executor._tasks = {"first": first, "second": second}
        executor.collector_queue = TwoReportQueue([first_report, second_report], stop)

        with self.assertRaises(InvalidStateError):
            executor._collect_work_queue_results()

        self.assertNotIn("first", executor.tasks)
        self.assertIn("second", executor.tasks)
        self.assertTrue(second.done())
        self.assertIn("work queue executor failed", str(second.exception()))

    def test_cancelled_failure_report_also_terminates_current_collector(self):
        stop = multiprocessing.Value("b", False)
        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
        executor.should_stop = stop
        executor.submit_process = type("Alive", (), {"is_alive": lambda self: True})()
        executor.tasks_lock = threading.Lock()
        first = Future()
        self.assertTrue(first.cancel())
        second = Future()
        first_report = WqTaskToParsl("first", False, None, "worker-failure", 1)
        second_report = WqTaskToParsl("second", True, "/unused-second", None, None)
        executor._tasks = {"first": first, "second": second}
        executor.collector_queue = TwoReportQueue([first_report, second_report], stop)

        with self.assertRaises(InvalidStateError):
            executor._collect_work_queue_results()

        self.assertNotIn("first", executor.tasks)
        self.assertIn("second", executor.tasks)
        self.assertTrue(second.done())
        self.assertIn("work queue executor failed", str(second.exception()))


if __name__ == "__main__":
    unittest.main()
