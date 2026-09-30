"""Runtime probe for checkpoint serialization during DFK result completion."""

import tempfile
import unittest
from concurrent.futures import Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.memoization import BasicMemoizer
from parsl.dataflow.states import States


class MemoCheckpointResultFailureRuntimeTest(unittest.TestCase):
    def test_unpickleable_result_leaves_future_pending_currently(self):
        with tempfile.TemporaryDirectory() as run_dir:
            memoizer = BasicMemoizer(checkpoint_mode="task_exit")
            memoizer.run_dir = run_dir
            memoizer.memo_lookup_table = {}
            memoizer.checkpointed_tasks = 0

            app_future = Future()
            task_record = {
                "id": 1,
                "status": States.running,
                "time_returned": None,
                "hashsum": "task-hash",
                "memoize": True,
                "app_fu": app_future,
            }

            dfk = DataFlowKernel.__new__(DataFlowKernel)
            dfk.memoizer = memoizer
            dfk.wipe_task = lambda task_id: None
            dfk._update_task_state = lambda record, state: record.__setitem__("status", state)

            with self.assertRaises(Exception):
                dfk._complete_task_result(task_record, States.exec_done, lambda: None)

            self.assertFalse(app_future.done())
            self.assertEqual(task_record["status"], States.running)


if __name__ == "__main__":
    unittest.main()
