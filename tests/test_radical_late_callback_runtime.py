"""Runtime probe for a late Radical Pilot callback after cancellation."""

import types
import unittest
from concurrent.futures import Future
from unittest.mock import patch

from parsl.executors.radical import executor as radical_executor


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
    uid = "task-1"
    mode = "TASK_PROC"
    description = {"mode": "TASK_PROC"}
    exit_code = 0
    return_value = None
    exception = None
    stderr = ""
    name = uid


class RadicalLateCallbackRuntimeTest(unittest.TestCase):
    def test_done_after_cancel_raises_invalid_state_error(self):
        executor = radical_executor.RadicalPilotExecutor.__new__(
            radical_executor.RadicalPilotExecutor
        )
        future = Future()
        executor.future_tasks = {"task-1": future}
        task = FakeTask()

        with patch.object(radical_executor, "rp", RP, create=True):
            executor.task_state_cb(task, RP.CANCELED)
            self.assertTrue(future.cancelled())
            with self.assertRaises(Exception) as context:
                executor.task_state_cb(task, RP.DONE)

        self.assertEqual(type(context.exception).__name__, "InvalidStateError")

    def test_failed_after_cancel_raises_invalid_state_error(self):
        executor = radical_executor.RadicalPilotExecutor.__new__(
            radical_executor.RadicalPilotExecutor
        )
        future = Future()
        executor.future_tasks = {"task-1": future}
        task = FakeTask()
        task.mode = RP.TASK_EXECUTABLE
        task.description = {"mode": RP.TASK_EXECUTABLE}

        with patch.object(radical_executor, "rp", RP, create=True):
            executor.task_state_cb(task, RP.CANCELED)
            self.assertTrue(future.cancelled())
            with self.assertRaises(Exception) as context:
                executor.task_state_cb(task, RP.FAILED)

        self.assertEqual(type(context.exception).__name__, "InvalidStateError")


if __name__ == "__main__":
    unittest.main()
