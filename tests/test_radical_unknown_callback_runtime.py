"""Runtime probe for callbacks whose local Radical Pilot Future is gone."""

import types
import unittest
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


class UnknownTask:
    uid = "task-removed"
    mode = "TASK_PROC"
    description = {"mode": "TASK_PROC"}


class RadicalUnknownCallbackRuntimeTest(unittest.TestCase):
    def test_callback_for_removed_task_currently_raises_key_error(self):
        executor = radical_executor.RadicalPilotExecutor.__new__(
            radical_executor.RadicalPilotExecutor
        )
        executor.future_tasks = {}

        with patch.object(radical_executor, "rp", RP, create=True):
            with self.assertRaises(KeyError):
                executor.task_state_cb(UnknownTask(), RP.DONE)


if __name__ == "__main__":
    unittest.main()
