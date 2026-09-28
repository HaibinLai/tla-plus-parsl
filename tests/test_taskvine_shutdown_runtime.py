"""Runtime probe for TaskVine collector shutdown finalization."""

import threading
import unittest
from concurrent.futures import Future

from parsl.executors.taskvine.errors import TaskVineManagerFailure
from parsl.executors.taskvine.executor import TaskVineExecutor


class TaskVineShutdownRuntimeTest(unittest.TestCase):
    def test_collector_exit_fails_outstanding_future(self):
        executor = TaskVineExecutor.__new__(TaskVineExecutor)
        executor._should_stop = threading.Event()
        executor._should_stop.set()
        executor._tasks_lock = threading.Lock()
        future = Future()
        executor._tasks = {7: future}
        executor._outstanding_tasks_lock = threading.Lock()
        executor._outstanding_tasks = 1

        executor._collect_taskvine_results()

        with self.assertRaises(TaskVineManagerFailure):
            future.result()


if __name__ == "__main__":
    unittest.main()
