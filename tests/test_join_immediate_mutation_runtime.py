import threading
import unittest
from concurrent.futures import Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.states import States


class JoinImmediateMutationRuntimeTest(unittest.TestCase):
    def test_immediate_callback_then_list_mutation_drops_second_position_currently(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        completed = []
        kernel.render_future_description = lambda future: "inner"
        kernel._complete_task_result = lambda record, state, result: completed.append(result)
        kernel._complete_task_exception = lambda record, state, error: None
        kernel._log_std_streams = lambda record: None

        first = Future()
        second = Future()
        first.set_result("first")
        join_list = [first, second]
        record = {
            "id": "outer",
            "status": States.joining,
            "joins": join_list,
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }

        # The first callback is the immediate callback from an already-done
        # Future. The caller then mutates the aliased list before the second
        # Future completes.
        kernel.handle_join_update(record, first)
        join_list.pop()
        second.set_result("second")
        kernel.handle_join_update(record, second)

        self.assertEqual(completed, [["first"]])


if __name__ == "__main__":
    unittest.main()
