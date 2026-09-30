"""Runtime probe for Flux callable-object serialization error reporting."""

import itertools
import threading
import unittest
from unittest.mock import patch

from parsl.executors.flux.executor import FluxExecutor
from parsl.serialize.errors import SerializationError


class CallableObjectWithoutName:
    def __call__(self):
        return 1


class FluxSerializationErrorNameRuntimeTest(unittest.TestCase):
    def _executor(self):
        executor = FluxExecutor.__new__(FluxExecutor)
        executor._submission_lock = threading.Lock()
        executor._stop_event = threading.Event()
        executor._task_id_counter = itertools.count()
        executor.working_dir = "/tmp"
        return executor

    def test_callable_without_name_masks_type_error_currently(self):
        with patch("parsl.executors.flux.executor.pack_apply_message",
                   side_effect=TypeError("cannot serialize callable")):
            with self.assertRaises(AttributeError):
                self._executor().submit(CallableObjectWithoutName(), {})

    def test_named_function_reaches_serialization_error(self):
        def named_function():
            return 1

        with patch("parsl.executors.flux.executor.pack_apply_message",
                   side_effect=TypeError("cannot serialize callable")):
            with self.assertRaises(SerializationError):
                self._executor().submit(named_function, {})


if __name__ == "__main__":
    unittest.main()
