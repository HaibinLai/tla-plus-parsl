"""Runtime probe for collecting all failed inner join Futures."""

import threading
import unittest
from concurrent.futures import Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.errors import JoinError
from parsl.dataflow.states import States


class JoinFailureAggregationRuntimeTest(unittest.TestCase):
    def test_join_error_contains_each_failed_inner_future_in_list_order(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.failed = []
        kernel.completed = []
        kernel.render_future_description = lambda future: future.join_id
        kernel._complete_task_result = lambda record, state, result: None
        kernel._complete_task_exception = lambda record, state, error: (
            kernel.failed.append(error), record.__setitem__("status", state)
        )
        kernel._log_std_streams = lambda record: None

        first = Future()
        first.join_id = "first"
        first.set_exception(ValueError("first failure"))
        second = Future()
        second.join_id = "second"
        second.set_exception(RuntimeError("second failure"))
        record = {
            "id": "outer",
            "status": States.joining,
            "joins": [first, second],
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }

        kernel.handle_join_update(record, first)
        kernel.handle_join_update(record, second)

        self.assertEqual(record["status"], States.failed)
        self.assertEqual(len(kernel.failed), 1)
        error = kernel.failed[0]
        self.assertIsInstance(error, JoinError)
        self.assertEqual(
            [tid for _, tid in error.dependent_exceptions_tids],
            ["first", "second"],
        )


if __name__ == "__main__":
    unittest.main()
