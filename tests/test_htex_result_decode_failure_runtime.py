"""Runtime probe for corrupt HTEX result payloads after task-map removal."""

import pickle
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.high_throughput.executor import HighThroughputExecutor


class OneBatchQueue:
    def __init__(self, batch):
        self.batch = batch

    def get(self, timeout_ms=None):
        if self.batch is None:
            raise AssertionError("result worker unexpectedly requested another batch")
        batch, self.batch = self.batch, None
        return batch

    def close(self):
        return None


class HtexResultDecodeFailureRuntimeTest(unittest.TestCase):
    def test_corrupt_result_orphans_future_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        task_future = Future()
        executor._tasks = {17: task_future}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        corrupt = pickle.dumps({
            "type": "result",
            "task_id": 17,
            "result": b"02\nnot-a-pickle",
        })
        executor.incoming_q = OneBatchQueue([corrupt])

        with self.assertRaises(Exception):
            executor._result_queue_worker()

        self.assertNotIn(17, executor.tasks)
        self.assertFalse(task_future.done())


if __name__ == "__main__":
    unittest.main()
