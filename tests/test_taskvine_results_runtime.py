"""Runtime probes for TaskVine manager report and collector result handling."""

import queue
import tempfile
import threading
import unittest
from concurrent.futures import Future
from pathlib import Path

from parsl.executors.errors import ExecutorError
from parsl.executors.taskvine.errors import TaskVineManagerFailure, TaskVineTaskFailure
from parsl.executors.taskvine.executor import TaskVineExecutor
from parsl.executors.taskvine.utils import VineTaskToParsl
from parsl.serialize import serialize


class OneReportQueue:
    def __init__(self, report, stop):
        self.report = report
        self.stop = stop
        self.used = False

    def get(self, timeout=None):
        if not self.used:
            self.used = True
            self.stop.set()
            return self.report
        raise queue.Empty


class EmptyQueue:
    def get(self, timeout=None):
        raise queue.Empty


class FakeSubmitProcess:
    def __init__(self, alive):
        self.alive = alive

    def is_alive(self):
        return self.alive


class TaskVineResultsRuntimeTest(unittest.TestCase):
    def run_report(self, report, payload):
        stop = threading.Event()
        executor = TaskVineExecutor.__new__(TaskVineExecutor)
        executor._should_stop = stop
        executor._submit_process = FakeSubmitProcess(True)
        executor._finished_task_queue = OneReportQueue(report, stop)
        executor._tasks_lock = threading.Lock()
        future = Future()
        executor._tasks = {report.executor_id: future}
        executor._outstanding_tasks_lock = threading.Lock()
        executor._outstanding_tasks = 1
        if payload is not None:
            Path(report.result_file).write_bytes(payload)
        executor._collect_taskvine_results()
        return future

    def test_valid_result_file_resolves_future(self):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "result")
            report = VineTaskToParsl(1, True, path, None, 0)
            future = self.run_report(report, serialize({"answer": 42}))
            self.assertEqual(future.result(), {"answer": 42})

    def test_result_file_exception_is_taskvine_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "result")
            report = VineTaskToParsl(1, True, path, None, 0)
            stop = threading.Event()
            executor = self.executor_for(report, stop)
            future = executor._tasks[1]
            Path(path).write_bytes(serialize(ValueError("bad app")))
            executor._collect_taskvine_results()
            with self.assertRaises(TaskVineTaskFailure):
                future.result()

    def executor_for(self, report, stop, process_alive=True):
        executor = TaskVineExecutor.__new__(TaskVineExecutor)
        executor._should_stop = stop
        executor._submit_process = FakeSubmitProcess(process_alive)
        executor._finished_task_queue = OneReportQueue(report, stop)
        executor._tasks_lock = threading.Lock()
        executor._tasks = {report.executor_id: Future()}
        executor._outstanding_tasks_lock = threading.Lock()
        executor._outstanding_tasks = 1
        return executor

    def test_corrupt_result_file_is_taskvine_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "result")
            report = VineTaskToParsl(1, True, path, None, 0)
            stop = threading.Event()
            executor = self.executor_for(report, stop)
            future = executor._tasks[1]
            Path(path).write_bytes(b"not-a-pickle")
            executor._collect_taskvine_results()
            with self.assertRaises(TaskVineTaskFailure):
                future.result()

    def test_no_result_report_is_taskvine_failure(self):
        report = VineTaskToParsl(1, False, None, "resource exhausted", 1)
        stop = threading.Event()
        executor = self.executor_for(report, stop)
        future = executor._tasks[1]
        executor._collect_taskvine_results()
        with self.assertRaises(TaskVineTaskFailure):
            future.result()

    def test_manager_exit_fails_outstanding_future(self):
        stop = threading.Event()
        report = VineTaskToParsl(1, False, None, None, None)
        executor = self.executor_for(report, stop, process_alive=False)
        future = executor._tasks[1]

        with self.assertRaises(ExecutorError):
            executor._collect_taskvine_results()
        with self.assertRaises(TaskVineManagerFailure):
            future.result()


if __name__ == "__main__":
    unittest.main()
