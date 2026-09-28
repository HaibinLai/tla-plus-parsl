"""Runtime probe for duplicate/late TaskVine collector reports."""

import queue
import tempfile
import threading
import unittest
from concurrent.futures import Future
from pathlib import Path

from parsl.executors.taskvine.errors import TaskVineManagerFailure
from parsl.executors.taskvine.executor import TaskVineExecutor
from parsl.executors.taskvine.utils import VineTaskToParsl
from parsl.serialize import serialize


class DuplicateThenEmptyQueue:
    def __init__(self, reports, stop):
        self.reports = list(reports)
        self.stop = stop

    def get(self, timeout=None):
        if self.reports:
            report = self.reports.pop(0)
            if not self.reports:
                self.stop.set()
            return report
        raise queue.Empty


class AliveProcess:
    def is_alive(self):
        return True


class TaskVineDuplicateReportRuntimeTest(unittest.TestCase):
    def test_duplicate_report_exits_collector_and_fails_unrelated_future(self):
        with tempfile.TemporaryDirectory() as directory:
            result_path = str(Path(directory) / "result")
            Path(result_path).write_bytes(serialize("ok"))
            report = VineTaskToParsl(1, True, result_path, None, 0)
            stop = threading.Event()
            executor = TaskVineExecutor.__new__(TaskVineExecutor)
            executor._should_stop = stop
            executor._submit_process = AliveProcess()
            executor._finished_task_queue = DuplicateThenEmptyQueue([report, report], stop)
            executor._tasks_lock = threading.Lock()
            first = Future()
            unrelated = Future()
            executor._tasks = {1: first, 2: unrelated}
            executor._outstanding_tasks_lock = threading.Lock()
            executor._outstanding_tasks = 2

            with self.assertRaises(KeyError):
                executor._collect_taskvine_results()

            self.assertEqual(first.result(), "ok")
            # The first report completed task 1; the collector's finally path
            # marks task 2 as a manager failure before the duplicate crashes.
            with self.assertRaises(TaskVineManagerFailure):
                unrelated.result()


if __name__ == "__main__":
    unittest.main()
