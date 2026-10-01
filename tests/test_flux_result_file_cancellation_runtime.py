"""Runtime bridge for Flux result-file callbacks after wrapper cancellation."""

import tempfile
import unittest
from concurrent.futures import InvalidStateError
from pathlib import Path

from parsl.executors.flux import TaskResult
from parsl.executors.flux.executor import FluxFutureWrapper, _complete_future
from parsl.serialize import serialize


class CompletedFluxFuture:
    def cancelled(self):
        return False

    def result(self):
        return 0


class FluxResultFileCancellationRuntimeTest(unittest.TestCase):
    def test_late_valid_result_file_writes_cancelled_wrapper_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            result_path = Path(directory) / "result.pkl"
            result_path.write_bytes(serialize(TaskResult("late", None)))
            wrapper = FluxFutureWrapper()
            self.assertTrue(wrapper.cancel())

            with self.assertRaises(InvalidStateError):
                _complete_future(str(result_path), wrapper, CompletedFluxFuture())

            self.assertTrue(wrapper.cancelled())


if __name__ == "__main__":
    unittest.main()
