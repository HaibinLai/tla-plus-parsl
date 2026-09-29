"""Runtime probe for stale HTEX results with unknown task ids."""

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


class HtexUnknownTaskResultRuntimeTest(unittest.TestCase):
    def test_unknown_result_stops_current_worker_before_live_result(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        live = Future()
        executor._tasks = {2: live}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        messages = [
            pickle.dumps({"type": "result", "task_id": 1, "result": serialize("stale")}),
            pickle.dumps({"type": "result", "task_id": 2, "result": serialize("live")}),
        ]
        executor.incoming_q = OneBatchQueue(executor, messages)

        with self.assertRaises(KeyError):
            executor._result_queue_worker()

        self.assertIn(2, executor.tasks)
        self.assertFalse(live.done())


if __name__ == "__main__":
    unittest.main()
