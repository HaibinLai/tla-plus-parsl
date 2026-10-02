import threading
import unittest
from concurrent.futures import Future

from parsl.executors.workqueue.errors import WorkQueueFailure
from parsl.executors.workqueue.executor import WorkQueueExecutor


class WorkQueueFailureFanoutRuntimeTest(unittest.TestCase):
    def test_callback_mutation_strands_later_future_currently(self):
        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)

        class Stop:
            value = True

        executor.should_stop = Stop()
        executor.tasks_lock = threading.Lock()
        first = Future()
        second = Future()
        executor._tasks = {1: first, 2: second}

        def remove_first(_future):
            executor._tasks.pop(1, None)

        first.add_done_callback(remove_first)
        with self.assertRaises(RuntimeError):
            executor._collect_work_queue_results()

        with self.assertRaises(WorkQueueFailure):
            first.result()
        self.assertFalse(second.done())


if __name__ == "__main__":
    unittest.main()
