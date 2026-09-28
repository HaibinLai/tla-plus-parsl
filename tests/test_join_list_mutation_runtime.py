"""Runtime probe for mutable join_app result-list aliasing."""

import threading
import unittest
from concurrent.futures import Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.states import States


class JoinListMutationRuntimeTest(unittest.TestCase):
    def test_mutating_join_list_before_callback_changes_outer_result_currently(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        completed = []
        kernel.completed = completed
        kernel.failed = []
        kernel.render_future_description = lambda future: "inner"
        kernel._complete_task_result = lambda record, state, result: completed.append(result)
        kernel._complete_task_exception = lambda record, state, error: None
        kernel._log_std_streams = lambda record: None

        first = Future()
        second = Future()
        first.set_result(1)
        second.set_result(2)
        join_list = [first, second]
        record = {
            "id": "outer",
            "status": States.joining,
            "joins": join_list,
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }

        # This models a caller retaining and mutating the list returned by the
        # join app before the DFK processes the callback.
        join_list.clear()
        kernel.handle_join_update(record, first)

        self.assertEqual(completed, [[]])


if __name__ == "__main__":
    unittest.main()
