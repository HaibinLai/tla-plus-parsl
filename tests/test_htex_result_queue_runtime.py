"""Runtime probe for HTEX malformed result handling."""

import pickle
import threading
import unittest
from concurrent.futures import Future, InvalidStateError

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


class HtexResultQueueRuntimeTest(unittest.TestCase):
    def test_malformed_result_orphans_pending_future_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        task_future = Future()
        executor._tasks = {17: task_future}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        malformed = pickle.dumps({"type": "result", "task_id": 17})
        executor.incoming_q = OneBatchQueue([malformed])

        with self.assertRaises(BadMessage):
            executor._result_queue_worker()

        # The current worker pops before validating result/exception fields.
        self.assertNotIn(17, executor.tasks)
        self.assertFalse(task_future.done())

    def test_duplicate_result_crashes_worker_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        task_future = Future()
        executor._tasks = {23: task_future}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        result = pickle.dumps({
            "type": "result",
            "task_id": 23,
            "result": serialize("ok"),
        })
        executor.incoming_q = OneBatchQueue([result, result])

        with self.assertRaises(KeyError):
            executor._result_queue_worker()

        self.assertEqual(task_future.result(), "ok")

    def test_result_for_cancelled_future_crashes_worker_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        task_future = Future()
        task_future.cancel()
        executor._tasks = {31: task_future}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        result = pickle.dumps({
            "type": "result",
            "task_id": 31,
            "result": serialize("late-result"),
        })
        executor.incoming_q = OneBatchQueue([result])

        # The worker removes the task before calling Future.set_result, so a
        # terminal/cancelled Future turns a late frame into an uncaught
        # InvalidStateError and loses the task bookkeeping entry.
        with self.assertRaises(InvalidStateError):
            executor._result_queue_worker()
        self.assertNotIn(31, executor.tasks)


if __name__ == "__main__":
    unittest.main()
