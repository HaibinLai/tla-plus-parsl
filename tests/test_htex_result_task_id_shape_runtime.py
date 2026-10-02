"""Runtime probe for malformed HTEX result task IDs."""

import pickle
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.serialize.facade import serialize


class _OneBatchQueue:
    def __init__(self, batch):
        self.batch = batch

    def get(self, timeout_ms=None):
        batch, self.batch = self.batch, None
        return batch

    def close(self):
        return None


class HtexResultTaskIdShapeRuntimeTest(unittest.TestCase):
    def test_unhashable_result_id_stops_worker_before_valid_result_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        valid_future = Future()
        executor._tasks = {7: valid_future}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        malformed = pickle.dumps({"type": "result", "task_id": [], "result": b"bad"})
        valid = pickle.dumps({
            "type": "result", "task_id": 7, "result": serialize("ok"),
        })
        executor.incoming_q = _OneBatchQueue([malformed, valid])

        with self.assertRaises(TypeError):
            executor._result_queue_worker()

        self.assertFalse(valid_future.done())


if __name__ == "__main__":
    unittest.main()
