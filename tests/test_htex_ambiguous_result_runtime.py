"""Runtime probe for HTEX result messages with conflicting payload fields."""

import pickle
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.serialize.facade import serialize


class OneBatchQueue:
    def __init__(self, executor, batch):
        self.executor = executor
        self.batch = batch

    def get(self, timeout_ms=None):
        batch, self.batch = self.batch, None
        self.executor._result_queue_thread_exit.set()
        return batch

    def close(self):
        return None


class HtexAmbiguousResultRuntimeTest(unittest.TestCase):
    def test_result_field_wins_over_exception_field_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        future = Future()
        executor._tasks = {1: future}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        message = {
            "type": "result",
            "task_id": 1,
            "result": serialize("accepted-result"),
            "exception": serialize("ignored-exception"),
        }
        executor.incoming_q = OneBatchQueue(executor, [pickle.dumps(message)])

        executor._result_queue_worker()

        self.assertTrue(future.done())
        self.assertEqual(future.result(), "accepted-result")


if __name__ == "__main__":
    unittest.main()
