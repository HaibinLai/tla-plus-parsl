"""Runtime probes for RadicalPilot task-state callback mappings."""

import types
import unittest
from concurrent.futures import Future
from unittest.mock import patch

from parsl.app.errors import BashExitFailure
from parsl.executors.radical import executor as radical_executor
from parsl.serialize import serialize


RP = types.SimpleNamespace(
    RAPTOR_MASTER="raptor_master",
    RAPTOR_WORKER="raptor_worker",
    FAILED="FAILED",
    DONE="DONE",
    CANCELED="CANCELED",
    TASK_EXEC="TASK_EXEC",
    TASK_PROC="TASK_PROC",
    TASK_EXECUTABLE="TASK_EXECUTABLE",
    TASK_FUNCTION="TASK_FUNCTION",
)


class FakeTask:
    def __init__(self, uid="task-1", mode="TASK_PROC", description=None,
                 exit_code=0, return_value=None, exception=None, stderr=""):
        self.uid = uid
        self.mode = mode
        self.description = description or {"mode": mode}
        self.exit_code = exit_code
        self.return_value = return_value
        self.exception = exception
        self.stderr = stderr
        self.name = uid


class RadicalResultsRuntimeTest(unittest.TestCase):
    def executor_with_future(self):
        executor = radical_executor.RadicalPilotExecutor.__new__(radical_executor.RadicalPilotExecutor)
        future = Future()
        executor.future_tasks = {"task-1": future}
        return executor, future

    def test_done_bash_task_returns_exit_code(self):
        executor, future = self.executor_with_future()
        task = FakeTask(mode="TASK_EXEC", description={"mode": "TASK_EXEC"}, exit_code=3)

        with patch.object(radical_executor, "rp", RP, create=True):
            executor.task_state_cb(task, RP.DONE)

        self.assertEqual(future.result(), 3)

    def test_done_python_task_deserializes_return_value(self):
        executor, future = self.executor_with_future()
        task = FakeTask(
            mode="TASK_FUNCTION",
            description={"mode": "TASK_FUNCTION"},
            return_value=repr(serialize({"answer": 42})),
        )

        with patch.object(radical_executor, "rp", RP, create=True):
            executor.task_state_cb(task, RP.DONE)

        self.assertEqual(future.result(), {"answer": 42})

    def test_canceled_task_cancels_future(self):
        executor, future = self.executor_with_future()
        task = FakeTask()

        with patch.object(radical_executor, "rp", RP, create=True):
            executor.task_state_cb(task, RP.CANCELED)

        self.assertTrue(future.cancelled())

    def test_failed_bash_task_sets_bash_exit_failure(self):
        executor, future = self.executor_with_future()
        task = FakeTask(mode="TASK_EXEC", description={"mode": "TASK_EXEC"}, exit_code=9)

        with patch.object(radical_executor, "rp", RP, create=True):
            executor.task_state_cb(task, RP.FAILED)

        with self.assertRaises(BashExitFailure):
            future.result()

    def test_failed_task_without_exception_reproduces_invalid_exception_path(self):
        executor, future = self.executor_with_future()
        task = FakeTask(mode="TASK_FUNCTION", description={"mode": "TASK_FUNCTION"}, exception=None)

        with patch.object(radical_executor, "rp", RP, create=True):
            executor.task_state_cb(task, RP.FAILED)

        with self.assertRaises(TypeError):
            future.result()

    def test_master_failure_fails_all_outstanding_tasks(self):
        executor, future = self.executor_with_future()
        task = FakeTask(mode=RP.RAPTOR_MASTER, stderr="worker died")

        with patch.object(radical_executor, "rp", RP, create=True):
            executor.task_state_cb(task, RP.FAILED)

        with self.assertRaises(RuntimeError):
            future.result()


if __name__ == "__main__":
    unittest.main()
