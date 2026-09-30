"""Runtime probe for callable-object serialization error reporting."""

import threading
import unittest
from unittest.mock import patch

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.serialize.errors import SerializationError


class CallableObjectWithoutName:
    def __call__(self):
        return 1


class HtexSerializationErrorNameRuntimeTest(unittest.TestCase):
    def test_callable_without_name_masks_type_error_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor._executor_bad_state = threading.Event()
        executor.validate_resource_spec = lambda _: None

        with patch("parsl.executors.high_throughput.executor.pack_apply_message",
                   side_effect=TypeError("cannot serialize callable")):
            with self.assertRaises(AttributeError):
                executor.submit(CallableObjectWithoutName(), {})

    def test_named_function_reaches_serialization_error(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor._executor_bad_state = threading.Event()
        executor.validate_resource_spec = lambda _: None

        def named_function():
            return 1

        with patch("parsl.executors.high_throughput.executor.pack_apply_message",
                   side_effect=TypeError("cannot serialize callable")):
            with self.assertRaises(SerializationError):
                executor.submit(named_function, {})


if __name__ == "__main__":
    unittest.main()
