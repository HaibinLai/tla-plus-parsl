import unittest
import threading
from unittest.mock import patch

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.serialize.errors import SerializationError


class HtexSerializationFailureRuntimeTest(unittest.TestCase):
    def test_non_type_serialization_failure_escapes_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor._executor_bad_state = threading.Event()
        executor.validate_resource_spec = lambda _: None

        def raise_value_error(*_args, **_kwargs):
            raise ValueError("serializer implementation failure")

        with patch("parsl.executors.high_throughput.executor.pack_apply_message",
                   side_effect=raise_value_error):
            with self.assertRaises(ValueError):
                executor.submit(lambda: None, {},)

    def test_type_serialization_failure_is_normalized(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor._executor_bad_state = threading.Event()
        executor.validate_resource_spec = lambda _: None

        def raise_type_error(*_args, **_kwargs):
            raise TypeError("not serializable")

        with patch("parsl.executors.high_throughput.executor.pack_apply_message",
                   side_effect=raise_type_error):
            with self.assertRaises(SerializationError):
                executor.submit(lambda: None, {},)


if __name__ == "__main__":
    unittest.main()
