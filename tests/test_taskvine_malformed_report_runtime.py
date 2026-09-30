"""Runtime probe for malformed TaskVine completion reports."""

import multiprocessing
import queue
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.taskvine.executor import TaskVineExecutor
from parsl.executors.taskvine.utils import VineTaskToParsl
from parsl.executors.taskvine.errors import TaskVineManagerFailure


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


class TaskVineMalformedReportRuntimeTest(unittest.TestCase):
    def test_malformed_report_stops_collector_before_valid_report_currently(self):
        stop = multiprocessing.Value("b", False)
        executor = TaskVineExecutor.__new__(TaskVineExecutor)
        executor._should_stop = stop
        executor._submit_process = AliveProcess()
        valid = VineTaskToParsl(executor_id="task-2", result_received=False,
                                result_file=None, reason="worker failure", status=-1)
        executor._finished_task_queue = TwoReportQueue([MalformedReport(), valid])
        executor._tasks_lock = threading.Lock()
        executor._outstanding_tasks_lock = threading.Lock()
        executor._outstanding_tasks = 1
        future = Future()
        executor._tasks = {"task-2": future}

        with self.assertRaises(AttributeError):
            executor._collect_taskvine_results()

        self.assertTrue(future.done())
        with self.assertRaises(TaskVineManagerFailure):
            future.result()


if __name__ == "__main__":
    unittest.main()
