"""Runtime probe for duplicate/late WorkQueue collector reports."""

import multiprocessing
import queue
import tempfile
import threading
import unittest
from concurrent.futures import Future
from pathlib import Path

from parsl.executors.errors import ExecutorError
from parsl.executors.workqueue.errors import WorkQueueFailure
from parsl.executors.workqueue.executor import WorkQueueExecutor, WqTaskToParsl
from parsl.serialize import serialize


class DuplicateThenEmptyQueue:
    def __init__(self, reports, stop):
        self.reports = list(reports)
        self.stop = stop

    def get(self, timeout=None):
        if self.reports:
            return self.reports.pop(0)
        raise queue.Empty


class AliveProcess:
    def is_alive(self):
        return True


class WorkQueueDuplicateReportRuntimeTest(unittest.TestCase):
    def test_duplicate_report_exits_collector_and_fails_unrelated_future(self):
        with tempfile.TemporaryDirectory() as directory:
            result_path = str(Path(directory) / "result")
            Path(result_path).write_bytes(serialize("ok"))
            report = WqTaskToParsl("task-1", True, result_path, None, None)
            stop = multiprocessing.Value("b", False)
            executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
            executor.should_stop = stop
            executor.submit_process = AliveProcess()
            executor.collector_queue = DuplicateThenEmptyQueue([report, report], stop)
            executor.tasks_lock = threading.Lock()
            first = Future()
            unrelated = Future()
            executor._tasks = {"task-1": first, "task-2": unrelated}

            with self.assertRaises(KeyError):
                executor._collect_work_queue_results()

            self.assertEqual(first.result(), "ok")
            with self.assertRaises(WorkQueueFailure):
                unrelated.result()


if __name__ == "__main__":
    unittest.main()
