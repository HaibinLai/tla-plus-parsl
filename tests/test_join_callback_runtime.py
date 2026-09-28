"""Runtime probes for DataFlowKernel join callback gating and ordering."""

import threading
import unittest
from concurrent.futures import CancelledError, Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.errors import JoinError
from parsl.dataflow.states import States


class JoinCallbackRuntimeTest(unittest.TestCase):
    def kernel_for(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.render_future_description = lambda future: getattr(future, "join_id", "inner")
        kernel.completed = []
        kernel.failed = []
        kernel._complete_task_result = lambda record, state, result: (
            kernel.completed.append((state, result)), record.__setitem__("status", state)
        )
        kernel._complete_task_exception = lambda record, state, error: (
            kernel.failed.append((state, error)), record.__setitem__("status", state)
        )
        kernel._log_std_streams = lambda record: None
        return kernel

    def record_for(self, futures):
        return {
            "id": "outer",
            "status": States.joining,
            "joins": futures,
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }

    def future(self, value=None, error=None, join_id="inner"):
        future = Future()
        future.join_id = join_id
        if error is not None:
            future.set_exception(error)
        elif value is not None:
            future.set_result(value)
        return future

    def test_early_callback_does_not_finalize_outer_join(self):
        kernel = self.kernel_for()
        first = self.future(1, join_id="first")
        second = Future()
        record = self.record_for([first, second])

        kernel.handle_join_update(record, first)

        self.assertEqual(record["status"], States.joining)
        self.assertEqual(kernel.completed, [])
        self.assertEqual(kernel.failed, [])

    def test_final_callback_preserves_list_order_and_duplicate_callback_is_harmless(self):
        kernel = self.kernel_for()
        first = self.future(1, join_id="first")
        second = self.future(2, join_id="second")
        record = self.record_for([second, first, first])

        kernel.handle_join_update(record, first)

        self.assertEqual(kernel.completed, [(States.exec_done, [2, 1, 1])])
        self.assertEqual(record["status"], States.exec_done)

        kernel.handle_join_update(record, first)
        self.assertEqual(len(kernel.completed), 1)

    def test_all_done_failure_becomes_join_error_with_inner_exception(self):
        kernel = self.kernel_for()
        first = self.future(1, join_id="first")
        second = self.future(error=RuntimeError("inner failed"), join_id="second")
        record = self.record_for([first, second])

        kernel.handle_join_update(record, second)

        self.assertEqual(record["status"], States.failed)
        self.assertEqual(len(kernel.failed), 1)
        self.assertIsInstance(kernel.failed[0][1], JoinError)
        self.assertEqual(len(kernel.failed[0][1].dependent_exceptions_tids), 1)

    def test_cancelled_inner_raises_and_leaves_outer_joining(self):
        kernel = self.kernel_for()
        inner = Future()
        inner.cancel()
        record = self.record_for(inner)

        with self.assertRaises(CancelledError):
            kernel.handle_join_update(record, inner)

        self.assertEqual(record["status"], States.joining)
        self.assertEqual(kernel.completed, [])
        self.assertEqual(kernel.failed, [])


if __name__ == "__main__":
    unittest.main()
