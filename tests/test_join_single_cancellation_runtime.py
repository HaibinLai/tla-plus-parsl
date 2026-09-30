"""Runtime probe for a cancelled single inner join Future."""

import threading
import unittest
from concurrent.futures import CancelledError, Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.states import States


class JoinSingleCancellationRuntimeTest(unittest.TestCase):
    def test_cancelled_single_inner_raises_and_leaves_outer_joining_currently(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.completed = []
        kernel.failed = []
        kernel.render_future_description = lambda future: "inner"
        kernel._complete_task_result = lambda record, state, result: kernel.completed.append(result)
        kernel._complete_task_exception = lambda record, state, error: kernel.failed.append(error)
        kernel._log_std_streams = lambda record: None

        inner = Future()
        inner.cancel()
        record = {
            "id": "outer",
            "status": States.joining,
            "joins": inner,
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }

        with self.assertRaises(CancelledError):
            kernel.handle_join_update(record, inner)

        self.assertEqual(record["status"], States.joining)
        self.assertEqual(kernel.completed, [])
        self.assertEqual(kernel.failed, [])

    def test_already_cancelled_inner_immediate_callback_leaves_outer_joining_currently(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.completed = []
        kernel.failed = []
        kernel.render_future_description = lambda future: "inner"
        kernel._complete_task_result = lambda record, state, result: kernel.completed.append(result)
        kernel._complete_task_exception = lambda record, state, error: kernel.failed.append(error)
        kernel._log_std_streams = lambda record: None

        inner = Future()
        inner.cancel()
        record = {
            "id": "outer",
            "status": States.joining,
            "joins": inner,
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }

        # add_done_callback invokes the callback synchronously for an already
        # terminal Future; concurrent.futures logs the callback exception and
        # leaves the outer record in joining under the current implementation.
        inner.add_done_callback(lambda future: kernel.handle_join_update(record, future))

        self.assertEqual(record["status"], States.joining)
        self.assertEqual(kernel.completed, [])
        self.assertEqual(kernel.failed, [])


if __name__ == "__main__":
    unittest.main()
