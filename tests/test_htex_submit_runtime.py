"""Runtime probe for HTEX submit queue failure bookkeeping."""

import unittest
from concurrent.futures import Future

from parsl.executors.high_throughput.executor import HighThroughputExecutor


class FailingOutgoingQueue:
    def put(self, message):
        raise OSError("outgoing queue closed")


class HtexSubmitRuntimeTest(unittest.TestCase):
    def test_queue_failure_leaves_pending_future_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor._executor_bad_state = __import__("threading").Event()
        executor._task_counter = 0
        executor._tasks = {}
        executor.outgoing_q = FailingOutgoingQueue()

        with self.assertRaises(OSError):
            future = executor.submit_payload({}, b"serialized-task")

        self.assertEqual(executor._task_counter, 1)
        self.assertEqual(list(executor._tasks), [1])
        orphan = executor._tasks[1]
        self.assertIsInstance(orphan, Future)
        self.assertFalse(orphan.done())


if __name__ == "__main__":
    unittest.main()
