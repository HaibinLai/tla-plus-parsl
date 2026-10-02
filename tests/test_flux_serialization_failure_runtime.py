"""Runtime probe for Flux non-TypeError serializer failure normalization."""

import itertools
import threading
import unittest
from unittest.mock import patch

from parsl.executors.flux.executor import FluxExecutor


class FluxSerializationFailureRuntimeTest(unittest.TestCase):
    def _executor(self):
        executor = FluxExecutor.__new__(FluxExecutor)
        executor._submission_lock = threading.Lock()
        executor._stop_event = threading.Event()
        executor._task_id_counter = itertools.count()
        executor.working_dir = "/tmp"
        return executor

    def test_non_type_serializer_failure_escapes_currently(self):
        def named_function():
            return 1

        with patch(
            "parsl.executors.flux.executor.pack_apply_message",
            side_effect=ValueError("serializer failed"),
        ):
            with self.assertRaises(ValueError):
                self._executor().submit(named_function, {})


if __name__ == "__main__":
    unittest.main()
