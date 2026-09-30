"""Runtime probes for WorkQueue collector result-file handling."""

import multiprocessing
import queue
import tempfile
import threading
import unittest
from concurrent.futures import Future
from pathlib import Path

from parsl.executors.workqueue.executor import WorkQueueExecutor, WqTaskToParsl
from parsl.executors.workqueue.errors import WorkQueueFailure, WorkQueueTaskFailure
from parsl.executors.errors import ExecutorError
from parsl.serialize import serialize


class OneReportQueue:
    def __init__(self, report, stop):
        self.report = report
        self.stop = stop
        self.used = False

    def get(self, timeout=None):
        if not self.used:
            self.used = True
            self.stop.value = True
            return self.report
        raise queue.Empty


class SequenceReportQueue:
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


class AlwaysEmptyQueue:
    def get(self, timeout=None):
        raise queue.Empty


class AliveProcess:
    def __init__(self, alive):
        self.alive = alive

    def is_alive(self):
        return self.alive


class WorkQueueResultsRuntimeTest(unittest.TestCase):
    def run_report(self, report, payload, process_alive=True):
        stop = multiprocessing.Value("b", False)
        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
        executor.should_stop = stop
        executor.submit_process = AliveProcess(process_alive)
        executor.collector_queue = OneReportQueue(report, stop)
        executor.tasks_lock = threading.Lock()
        future = Future()
        executor._tasks = {report.id: future}
        if payload is not None:
            Path(report.result_file).write_bytes(payload)
        executor._collect_work_queue_results()
        return future

    def test_valid_result_file_resolves_future(self):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "result")
            report = WqTaskToParsl("task-1", True, path, None, None)
            future = self.run_report(report, serialize({"answer": 42}))
            self.assertEqual(future.result(), {"answer": 42})

    def test_serialized_exception_becomes_workqueue_task_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "result")
            report = WqTaskToParsl("task-1", True, path, None, None)
            future = self.run_report(report, serialize(ValueError("bad app")))
            with self.assertRaises(WorkQueueTaskFailure):
                future.result()

    def test_corrupt_result_file_becomes_workqueue_task_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "result")
            report = WqTaskToParsl("task-1", True, path, None, None)
            future = self.run_report(report, b"not-a-pickle")
            with self.assertRaises(WorkQueueTaskFailure):
                future.result()

    def test_collector_failure_marks_outstanding_future(self):
        stop = multiprocessing.Value("b", False)
        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
        executor.should_stop = stop
        executor.submit_process = AliveProcess(False)
        executor.collector_queue = AlwaysEmptyQueue()
        executor.tasks_lock = threading.Lock()
        future = Future()
        executor._tasks = {"task-1": future}

        with self.assertRaises(ExecutorError):
            executor._collect_work_queue_results()

        with self.assertRaises(WorkQueueFailure):
            future.result()

    def test_cancelled_failure_report_aborts_collector_before_next_report_currently(self):
        stop = multiprocessing.Value("b", False)
        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
        executor.should_stop = stop
        executor.submit_process = AliveProcess(True)
        executor.tasks_lock = threading.Lock()
        first = WqTaskToParsl("task-1", False, None, "first failure", None)
        second = WqTaskToParsl("task-2", True, "/tmp/unused-result", None, None)
        first_future = Future()
        self.assertTrue(first_future.cancel())
        second_future = Future()
        executor._tasks = {"task-1": first_future, "task-2": second_future}
        executor.collector_queue = SequenceReportQueue([first, second], stop)

        with self.assertRaises(Exception):
            executor._collect_work_queue_results()

        self.assertNotIn("task-1", executor.tasks)
        self.assertTrue(second_future.done())


if __name__ == "__main__":
    unittest.main()
