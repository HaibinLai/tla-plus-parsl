import threading
import unittest
from concurrent.futures import Future

from parsl.executors.taskvine.executor import TaskVineExecutor
from parsl.executors.taskvine.errors import TaskVineManagerFailure


class TaskVineFailureFanoutRuntimeTest(unittest.TestCase):
    def test_callback_mutation_strands_later_future_currently(self):
        executor = TaskVineExecutor.__new__(TaskVineExecutor)
        executor._should_stop = threading.Event()
        executor._should_stop.set()
        executor._tasks_lock = threading.Lock()
        first = Future()
        second = Future()
        executor._tasks = {1: first, 2: second}
        executor._outstanding_tasks_lock = threading.Lock()
        executor._outstanding_tasks = 2

        def remove_first(_future):
            executor.tasks.pop(1, None)

        first.add_done_callback(remove_first)
        with self.assertRaises(RuntimeError):
            executor._collect_taskvine_results()

        with self.assertRaises(TaskVineManagerFailure):
            first.result()
        self.assertFalse(second.done())


if __name__ == "__main__":
    unittest.main()
