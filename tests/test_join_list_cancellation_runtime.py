"""Runtime probe for cancelled inner Futures in list-valued join_app callbacks."""

import threading
import unittest
from concurrent.futures import Future, CancelledError

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.states import States


class JoinListCancellationRuntimeTest(unittest.TestCase):
    def test_cancelled_inner_in_list_leaves_outer_joining_currently(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.completed = []
        kernel.failed = []
        kernel.render_future_description = lambda future: "inner"
        kernel._complete_task_result = lambda record, state, result: (
            kernel.completed.append((state, result)),
            record.__setitem__("status", state),
        )
        kernel._complete_task_exception = lambda record, state, error: (
            kernel.failed.append((state, error)),
            record.__setitem__("status", state),
        )
        kernel._log_std_streams = lambda record: None

        successful = Future()
        successful.set_result(1)
        cancelled = Future()
        cancelled.cancel()
        record = {
            "id": "outer",
            "status": States.joining,
            "joins": [successful, cancelled],
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }

        with self.assertRaises(CancelledError):
            kernel.handle_join_update(record, cancelled)

        self.assertEqual(record["status"], States.joining)
        self.assertEqual(kernel.completed, [])
        self.assertEqual(kernel.failed, [])

    def test_three_element_list_still_escapes_on_cancelled_inner_currently(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.completed = []
        kernel.failed = []
        kernel.render_future_description = lambda future: "inner"
        kernel._complete_task_result = lambda record, state, result: (
            kernel.completed.append((state, result)),
            record.__setitem__("status", state),
        )
        kernel._complete_task_exception = lambda record, state, error: (
            kernel.failed.append((state, error)),
            record.__setitem__("status", state),
        )
        first, cancelled, third = Future(), Future(), Future()
        first.set_result(1)
        cancelled.cancel()
        third.set_result(3)
        record = {
            "id": "outer-three",
            "status": States.joining,
            "joins": [first, cancelled, third],
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }

        with self.assertRaises(CancelledError):
            kernel.handle_join_update(record, cancelled)

        self.assertEqual(record["status"], States.joining)
        self.assertEqual(kernel.completed, [])
        self.assertEqual(kernel.failed, [])


if __name__ == "__main__":
    unittest.main()
