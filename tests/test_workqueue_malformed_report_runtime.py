"""Runtime probe for malformed Work Queue result reports."""

import multiprocessing
import queue
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.workqueue.executor import WorkQueueExecutor, WqTaskToParsl
from parsl.executors.workqueue.errors import WorkQueueFailure
from parsl.executors.errors import ExecutorError


class AliveProcess:
    def is_alive(self):
        return True


class TwoReportQueue:
    def __init__(self, reports):
        self.reports = list(reports)

    def get(self, timeout=None):
        if self.reports:
            return self.reports.pop(0)
        raise queue.Empty


class MalformedReport:
    result_received = False


class WorkQueueMalformedReportRuntimeTest(unittest.TestCase):
    def test_malformed_report_stops_collector_before_valid_report_currently(self):
        stop = multiprocessing.Value("b", False)
        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
        executor.should_stop = stop
        executor.submit_process = AliveProcess()
        valid = WqTaskToParsl("task-2", False, None, "worker failure", None)
        executor.collector_queue = TwoReportQueue([MalformedReport(), valid])
        executor.tasks_lock = threading.Lock()
        future = Future()
        executor._tasks = {"task-2": future}

        with self.assertRaises(AttributeError):
            executor._collect_work_queue_results()

        self.assertTrue(future.done())
        with self.assertRaises(WorkQueueFailure):
            future.result()


if __name__ == "__main__":
    unittest.main()
