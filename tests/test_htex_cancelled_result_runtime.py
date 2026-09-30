"""Runtime probe for HTEX result delivery after Future cancellation."""

import pickle
import threading
import unittest
from concurrent.futures import Future, InvalidStateError

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


class HtexCancelledResultRuntimeTest(unittest.TestCase):
    def test_cancelled_future_result_stops_current_worker_and_orphans_next(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        cancelled = Future()
        self.assertTrue(cancelled.cancel())
        pending = Future()
        executor._tasks = {1: cancelled, 2: pending}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        messages = [
            pickle.dumps({"type": "result", "task_id": 1, "result": serialize("cancelled-result")}),
            pickle.dumps({"type": "result", "task_id": 2, "result": serialize("live-result")}),
        ]
        executor.incoming_q = OneBatchQueue(executor, messages)

        with self.assertRaises(InvalidStateError):
            executor._result_queue_worker()

        self.assertNotIn(1, executor.tasks)
        self.assertIn(2, executor.tasks)
        self.assertFalse(pending.done())

    def test_cancelled_future_failure_stops_current_worker_and_orphans_next(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        cancelled = Future()
        self.assertTrue(cancelled.cancel())
        pending = Future()
        executor._tasks = {1: cancelled, 2: pending}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        messages = [
            pickle.dumps({
                "type": "result",
                "task_id": 1,
                "exception": serialize(ValueError("cancelled-failure")),
            }),
            pickle.dumps({
                "type": "result",
                "task_id": 2,
                "exception": serialize(ValueError("live-failure")),
            }),
        ]
        executor.incoming_q = OneBatchQueue(executor, messages)

        with self.assertRaises(InvalidStateError):
            executor._result_queue_worker()

        self.assertNotIn(1, executor.tasks)
        self.assertIn(2, executor.tasks)
        self.assertFalse(pending.done())


if __name__ == "__main__":
    unittest.main()
