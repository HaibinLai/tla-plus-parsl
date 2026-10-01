"""Runtime bridge for Radical-Pilot malformed Python result payloads."""

import types
import unittest
from concurrent.futures import Future
from unittest.mock import patch

from parsl.executors.radical import executor as radical_executor


RP = types.SimpleNamespace(
    RAPTOR_MASTER="raptor_master",
    RAPTOR_WORKER="raptor_worker",
    DONE="DONE",
    TASK_EXEC="TASK_EXEC",
    TASK_PROC="TASK_PROC",
    TASK_EXECUTABLE="TASK_EXECUTABLE",
    TASK_FUNCTION="TASK_FUNCTION",
)


class FakeTask:
    uid = "task-1"
    mode = "TASK_FUNCTION"
    description = {"mode": "TASK_FUNCTION"}
    return_value = "b'not-a-serializer-envelope'"


class RadicalDecodeFailureRuntimeTest(unittest.TestCase):
    def test_malformed_done_payload_leaves_future_pending_currently(self):
        executor = radical_executor.RadicalPilotExecutor.__new__(radical_executor.RadicalPilotExecutor)
        future = Future()
        executor.future_tasks = {"task-1": future}

        with patch.object(radical_executor, "rp", RP, create=True):
            with self.assertRaises(ValueError):
                executor.task_state_cb(FakeTask(), RP.DONE)

        self.assertFalse(future.done())


if __name__ == "__main__":
    unittest.main()
