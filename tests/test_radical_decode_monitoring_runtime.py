"""Runtime bridge for Radical-Pilot decode failure and collector progress."""

import types
import unittest
from concurrent.futures import Future
from unittest.mock import patch

from parsl.executors.radical import executor as radical_executor
from parsl.serialize import serialize


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
    def __init__(self, uid, return_value):
        self.uid = uid
        self.mode = "TASK_FUNCTION"
        self.description = {"mode": "TASK_FUNCTION"}
        self.return_value = return_value


class RadicalDecodeMonitoringRuntimeTest(unittest.TestCase):
    def test_decode_exception_stops_callback_loop_and_hides_later_result(self):
        executor = radical_executor.RadicalPilotExecutor.__new__(
            radical_executor.RadicalPilotExecutor
        )
        first = Future()
        second = Future()
        executor.future_tasks = {"bad": first, "good": second}
        malformed = FakeTask("bad", "b'not-a-serializer-envelope'")
        valid = FakeTask("good", repr(serialize({"answer": 42})))

        # This is the smallest collector analogue: the real callback exception
        # escapes the receive loop, so the valid event after it is never seen.
        with patch.object(radical_executor, "rp", RP, create=True):
            try:
                executor.task_state_cb(malformed, RP.DONE)
            except ValueError:
                pass
            else:
                self.fail("malformed payload unexpectedly completed")

        self.assertFalse(first.done())
        self.assertFalse(second.done())

        # A fixed collector would continue after recording a terminal decode
        # failure; demonstrate that the later event itself is independently
        # consumable by the same callback implementation.
        with patch.object(radical_executor, "rp", RP, create=True):
            executor.task_state_cb(valid, RP.DONE)
        self.assertEqual(second.result(), {"answer": 42})


if __name__ == "__main__":
    unittest.main()
