"""Runtime probe for duplicate Future positions in JoinError."""

import threading
import unittest
from concurrent.futures import Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.errors import JoinError
from parsl.dataflow.states import States


class JoinDuplicateFailureAggregationRuntimeTest(unittest.TestCase):
    def test_failed_duplicate_future_contributes_two_entries(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.failed = []
        kernel.render_future_description = lambda future: future.join_id
        kernel._complete_task_exception = lambda record, state, error: (
            kernel.failed.append(error), record.__setitem__("status", state)
        )
        kernel._log_std_streams = lambda record: None

        failed = Future()
        failed.join_id = "same-inner"
        failed.set_exception(ValueError("inner failure"))
        record = {
            "id": "outer",
            "status": States.joining,
            "joins": [failed, failed],
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }

        kernel.handle_join_update(record, failed)

        self.assertEqual(record["status"], States.failed)
        self.assertEqual(len(kernel.failed), 1)
        error = kernel.failed[0]
        self.assertIsInstance(error, JoinError)
        self.assertEqual(
            [tid for _, tid in error.dependent_exceptions_tids],
            ["same-inner", "same-inner"],
        )


if __name__ == "__main__":
    unittest.main()
