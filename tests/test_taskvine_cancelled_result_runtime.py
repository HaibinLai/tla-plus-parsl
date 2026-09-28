"""Runtime probe for TaskVine result delivery after Future cancellation."""

import queue
import tempfile
import threading
import unittest
from concurrent.futures import Future, InvalidStateError
from pathlib import Path

from parsl.executors.taskvine.errors import TaskVineManagerFailure
from parsl.executors.taskvine.executor import TaskVineExecutor
from parsl.executors.taskvine.utils import VineTaskToParsl
from parsl.serialize import serialize


class TwoReportQueue:
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


class TaskVineCancelledResultRuntimeTest(unittest.TestCase):
    def test_cancelled_report_terminates_current_collector_and_fails_later_task(self):
        with tempfile.TemporaryDirectory() as directory:
            first_path = str(Path(directory) / "first")
            second_path = str(Path(directory) / "second")
            Path(first_path).write_bytes(serialize("cancelled-result"))
            Path(second_path).write_bytes(serialize("live-result"))
            first_report = VineTaskToParsl(1, True, first_path, None, 0)
            second_report = VineTaskToParsl(2, True, second_path, None, 0)

            stop = threading.Event()
            executor = TaskVineExecutor.__new__(TaskVineExecutor)
            executor._should_stop = stop
            executor._submit_process = AliveProcess()
            executor._finished_task_queue = TwoReportQueue([first_report, second_report], stop)
            executor._tasks_lock = threading.Lock()
            executor._outstanding_tasks_lock = threading.Lock()
            executor._outstanding_tasks = 2
            first = Future()
            self.assertTrue(first.cancel())
            second = Future()
            executor._tasks = {1: first, 2: second}

            with self.assertRaises(InvalidStateError):
                executor._collect_taskvine_results()

            self.assertNotIn(1, executor.tasks)
            self.assertIn(2, executor.tasks)
            self.assertTrue(second.done())
            self.assertIsInstance(second.exception(), TaskVineManagerFailure)


if __name__ == "__main__":
    unittest.main()
