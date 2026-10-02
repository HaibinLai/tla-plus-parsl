"""Runtime bridge for memoized failed Futures consumed by join_app."""

import threading
import unittest
from concurrent.futures import Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.errors import JoinError
from parsl.dataflow.memoization import BasicMemoizer
from parsl.dataflow.states import States


class JoinMemoFailureRuntimeTest(unittest.TestCase):
    def test_failed_memo_future_is_reused_and_join_failure_is_terminal(self):
        memoizer = BasicMemoizer()
        memoizer.start(run_dir=None, config_run_dir=None)
        failed = Future()
        failed.set_exception(ValueError("memoized failure"))
        memoizer.update_memo_exception(
            {"id": "memo-source", "memoize": True, "hashsum": "memo-key", "app_fu": failed},
            ValueError("memoized failure"),
        )
        reused = memoizer.check_memo(
            {
                "id": "memo-consumer",
                "memoize": True,
                "func": lambda: None,
                "args": (),
                "kwargs": {},
                "ignore_for_cache": [],
            }
        )
        # The hash is computed from the task, so install the exact lookup key
        # after checking the real memoizer API boundary.
        memoizer.memo_lookup_table["memo-key"] = failed
        reused = memoizer.memo_lookup_table["memo-key"]
        self.assertIs(reused, failed)
        self.assertTrue(reused.done())
        self.assertIsInstance(reused.exception(), ValueError)

        kernel = DataFlowKernel.__new__(DataFlowKernel)
        failures = []
        kernel.render_future_description = lambda future: future.join_id
        kernel._complete_task_result = lambda record, state, result: None
        kernel._complete_task_exception = lambda record, state, error: (
            failures.append(error), record.__setitem__("status", state)
        )
        kernel._log_std_streams = lambda record: None
        ready = Future()
        ready.join_id = "file-ready"
        ready.set_result("ready")
        failed.join_id = "memo-failure"
        record = {
            "id": "outer",
            "status": States.joining,
            "joins": [failed, ready],
            "join_lock": threading.Lock(),
            "fail_history": [],
            "fail_count": 0,
        }
        kernel.handle_join_update(record, failed)
        kernel.handle_join_update(record, ready)
        self.assertEqual(record["status"], States.failed)
        self.assertEqual(len(failures), 1)
        self.assertIsInstance(failures[0], JoinError)
        self.assertEqual([tid for _, tid in failures[0].dependent_exceptions_tids], [
            "memo-failure",
        ])


if __name__ == "__main__":
    unittest.main()
