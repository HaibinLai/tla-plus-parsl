"""Runtime probe for a corrupt result followed by a valid result in one batch."""

import pickle
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.serialize import serialize


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


class HtexResultDecodeContinuationRuntimeTest(unittest.TestCase):
    def test_corrupt_first_frame_stops_before_valid_second_frame_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        first = Future()
        second = Future()
        executor._tasks = {17: first, 18: second}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        corrupt = pickle.dumps({
            "type": "result",
            "task_id": 17,
            "result": b"02\nnot-a-pickle",
        })
        valid = pickle.dumps({
            "type": "result",
            "task_id": 18,
            "result": serialize(42),
        })
        executor.incoming_q = OneBatchQueue([corrupt, valid])

        with self.assertRaises(Exception):
            executor._result_queue_worker()

        self.assertNotIn(17, executor.tasks)
        self.assertIn(18, executor.tasks)
        self.assertFalse(first.done())
        self.assertFalse(second.done())


if __name__ == "__main__":
    unittest.main()
