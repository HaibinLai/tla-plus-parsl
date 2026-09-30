"""Runtime probe for three-inner-Future join ordering and duplicate positions."""

import threading
import unittest
from concurrent.futures import Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.states import States


class JoinThreeListRuntimeTest(unittest.TestCase):
    def test_three_inner_futures_preserve_four_list_positions(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.completed = []
        kernel.failed = []
        kernel.render_future_description = lambda future: future.join_id
        kernel._complete_task_result = lambda record, state, result: (
            kernel.completed.append(result), record.__setitem__("status", state)
        )
        kernel._complete_task_exception = lambda record, state, error: (
            kernel.failed.append(error), record.__setitem__("status", state)
        )
        kernel._log_std_streams = lambda record: None

        futures = []
        for join_id, value in (("one", 1), ("two", 2), ("three", 3)):
            future = Future()
            future.join_id = join_id
            future.set_result(value)
            futures.append(future)

        record = {
            "id": "outer",
            "status": States.joining,
            "joins": [futures[2], futures[0], futures[1], futures[0]],
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }

        kernel.handle_join_update(record, futures[0])

        self.assertEqual(record["status"], States.exec_done)
        self.assertEqual(kernel.completed, [[3, 1, 2, 1]])
        self.assertEqual(kernel.failed, [])


if __name__ == "__main__":
    unittest.main()
