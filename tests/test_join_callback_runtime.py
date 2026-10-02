"""Runtime probes for DataFlowKernel join callback gating and ordering."""

import datetime
import tempfile
import threading
import unittest
from concurrent.futures import CancelledError, Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.errors import JoinError
from parsl.monitoring.db_manager import Database, STATUS, WORKFLOW
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

    def test_reverse_completion_preserves_original_join_list_order(self):
        kernel = self.kernel_for()
        first = self.future(1, join_id="first")
        second = self.future(2, join_id="second")
        record = self.record_for([first, second])

        # Both inner Futures are already complete, but the callback that
        # triggers finalization is the second one. Result construction must
        # still follow the original [first, second] join-list order.
        kernel.handle_join_update(record, second)

        self.assertEqual(kernel.completed, [(States.exec_done, [1, 2])])

    def test_concurrent_duplicate_callbacks_finalize_once(self):
        """The real join lock permits only one terminal completion."""
        kernel = self.kernel_for()
        first = self.future(1, join_id="first")
        second = self.future(2, join_id="second")
        record = self.record_for([first, second])
        barrier = threading.Barrier(2)
        errors = []

        def invoke_callback():
            try:
                barrier.wait(timeout=2)
                kernel.handle_join_update(record, first)
            except Exception as exc:  # pragma: no cover - diagnostic path
                errors.append(exc)

        workers = [threading.Thread(target=invoke_callback) for _ in range(2)]
        for worker in workers:
            worker.start()
        for worker in workers:
            worker.join(timeout=2)

        self.assertEqual(errors, [])
        self.assertEqual(record["status"], States.exec_done)
        self.assertEqual(kernel.completed, [(States.exec_done, [1, 2])])

    def test_duplicate_callbacks_publish_one_monitoring_terminal_row(self):
        """Callback idempotence must hold for the SQLite monitoring history."""
        with tempfile.TemporaryDirectory() as directory:
            database = Database("sqlite:///" + directory + "/monitoring.db")
            now = datetime.datetime.now()
            database.insert(table=WORKFLOW, messages=[{
                "run_id": "join-callback-monitoring",
                "time_began": now,
                "host": "host",
                "user": "user",
                "rundir": directory,
                "tasks_failed_count": 0,
                "tasks_completed_count": 0,
            }])

            kernel = self.kernel_for()
            record = self.record_for([
                self.future(1, join_id="first"),
                self.future(2, join_id="second"),
            ])
            record["id"] = 91

            def complete_and_monitor(task_record, state, result):
                task_record["status"] = state
                database.insert(table=STATUS, messages=[{
                    "task_id": task_record["id"],
                    "run_id": "join-callback-monitoring",
                    "task_status_name": state.name,
                    "timestamp": datetime.datetime.now(),
                    "try_id": 0,
                }])

            kernel._complete_task_result = complete_and_monitor
            barrier = threading.Barrier(2)

            def invoke_callback():
                barrier.wait(timeout=2)
                kernel.handle_join_update(record, record["joins"][0])

            workers = [threading.Thread(target=invoke_callback) for _ in range(2)]
            for worker in workers:
                worker.start()
            for worker in workers:
                worker.join(timeout=2)

            rows = database.session.execute(
                database.meta.tables[STATUS].select()
                .where(database.meta.tables[STATUS].c.task_id == 91)
            ).fetchall()

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].task_status_name, States.exec_done.name)

    def test_concurrent_success_and_failure_callbacks_publish_one_join_error(self):
        """A mixed inner outcome must aggregate to one terminal JoinError."""
        kernel = self.kernel_for()
        success = self.future(1, join_id="success")
        failure = self.future(error=RuntimeError("inner failed"), join_id="failure")
        record = self.record_for([success, failure])
        barrier = threading.Barrier(2)
        errors = []

        def invoke_callback(inner):
            try:
                barrier.wait(timeout=2)
                kernel.handle_join_update(record, inner)
            except Exception as exc:  # pragma: no cover - diagnostic path
                errors.append(exc)

        workers = [
            threading.Thread(target=invoke_callback, args=(success,)),
            threading.Thread(target=invoke_callback, args=(failure,)),
        ]
        for worker in workers:
            worker.start()
        for worker in workers:
            worker.join(timeout=2)

        self.assertEqual(errors, [])
        self.assertEqual(kernel.completed, [])
        self.assertEqual(len(kernel.failed), 1)
        self.assertIsInstance(kernel.failed[0][1], JoinError)
        self.assertEqual(len(kernel.failed[0][1].dependent_exceptions_tids), 1)

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
