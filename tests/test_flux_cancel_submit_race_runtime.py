"""Runtime probe for Flux wrapper cancellation before underlying binding."""

import tempfile
import unittest
from concurrent.futures import InvalidStateError
from pathlib import Path

from parsl.executors.flux import TaskResult
from parsl.executors.flux.executor import FluxFutureWrapper, _complete_future
from parsl.serialize import serialize


class SuccessfulFluxFuture:
    def cancelled(self):
        return False

    def result(self):
        return 0


class FluxCancelSubmitRaceRuntimeTest(unittest.TestCase):
    def test_late_binding_after_cancel_causes_callback_state_error_currently(self):
        wrapper = FluxFutureWrapper()
        self.assertTrue(wrapper.cancel())

        # This is the interleaving between cancel() releasing its lock and the
        # submission thread assigning _flux_future.
        wrapper._flux_future = SuccessfulFluxFuture()
        with tempfile.TemporaryDirectory() as directory:
            result_path = Path(directory) / "result.pkl"
            result_path.write_bytes(serialize(TaskResult("late", None)))
            with self.assertRaises(InvalidStateError):
                _complete_future(str(result_path), wrapper, wrapper._flux_future)

        self.assertTrue(wrapper.cancelled())


if __name__ == "__main__":
    unittest.main()
