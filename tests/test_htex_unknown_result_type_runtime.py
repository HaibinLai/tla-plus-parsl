"""Runtime probe for unknown HTEX result types stopping the result worker."""

import pickle
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.errors import BadMessage
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


class HtexUnknownResultTypeRuntimeTest(unittest.TestCase):
    def test_unknown_result_type_stops_worker_before_valid_frame_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        task_future = Future()
        executor._tasks = {42: task_future}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        unknown = pickle.dumps({"type": "telemetry", "payload": "ignored"})
        valid = pickle.dumps({
            "type": "result",
            "task_id": 42,
            "result": serialize("ok"),
        })
        executor.incoming_q = OneBatchQueue([unknown, valid])

        with self.assertRaises(BadMessage):
            executor._result_queue_worker()

        self.assertFalse(task_future.done())


if __name__ == "__main__":
    unittest.main()
