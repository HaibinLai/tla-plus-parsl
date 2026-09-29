"""Runtime probe for executor-side corrupt outer pickle frames."""

import pickle
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.serialize.facade import serialize


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


class HtexExecutorResultFrameContinuationRuntimeTest(unittest.TestCase):
    def test_corrupt_outer_pickle_aborts_later_valid_result_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        first = Future()
        second = Future()
        executor._tasks = {17: first, 18: second}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        valid = pickle.dumps({
            "type": "result",
            "task_id": 18,
            "result": serialize("later-result"),
        })
        executor.incoming_q = OneBatchQueue([b"not-an-outer-pickle", valid])

        with self.assertRaises((pickle.UnpicklingError, EOFError, ValueError)):
            executor._result_queue_worker()

        self.assertFalse(first.done())
        self.assertFalse(second.done())
        self.assertEqual(set(executor.tasks), {17, 18})


if __name__ == "__main__":
    unittest.main()
