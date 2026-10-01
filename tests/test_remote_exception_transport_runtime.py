"""Runtime bridge for serialized RemoteExceptionWrapper cause preservation."""

import pickle
import threading
import unittest
from concurrent.futures import Future

from parsl.app.errors import RemoteExceptionWrapper
from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.serialize.facade import serialize


class OneBatchQueue:
    def __init__(self, batch, stop):
        self.batch = batch
        self.stop = stop

    def get(self, timeout_ms=None):
        if self.batch is None:
            raise AssertionError("result worker unexpectedly requested another batch")
        batch, self.batch = self.batch, None
        self.stop.set()
        return batch

    def close(self):
        return None


class RemoteExceptionTransportRuntimeTest(unittest.TestCase):
    def test_htex_result_worker_reraises_serialized_cause_chain(self):
        try:
            try:
                raise ValueError("leaf")
            except ValueError as leaf:
                root = RuntimeError("root")
                root.__cause__ = leaf
                wrapper = RemoteExceptionWrapper(type(root), root, root.__traceback__)
        except Exception:
            raise AssertionError("fixture construction failed")

        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        task_future = Future()
        executor._tasks = {41: task_future}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        result = pickle.dumps({
            "type": "result",
            "task_id": 41,
            "exception": serialize(wrapper),
        })
        executor.incoming_q = OneBatchQueue([result], executor._result_queue_thread_exit)
        try:
            executor._result_queue_worker()
        except Exception as exc:
            self.fail(f"result worker leaked exception: {exc!r}")

        error = task_future.exception()
        self.assertIsInstance(error, RuntimeError)
        self.assertIsInstance(error.__cause__, ValueError)
        self.assertEqual(str(error.__cause__), "leaf")


if __name__ == "__main__":
    unittest.main()
