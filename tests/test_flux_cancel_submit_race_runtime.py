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


class CancellableFluxFuture:
    def __init__(self):
        self.was_cancelled = False

    def cancelled(self):
        return self.was_cancelled

    def cancel(self):
        self.was_cancelled = True
        return True

    def running(self):
        return not self.was_cancelled


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

    def test_cancel_while_wrapper_running_raises_after_cancelling_underlying_currently(self):
        wrapper = FluxFutureWrapper()
        underlying = CancellableFluxFuture()
        wrapper._flux_future = underlying
        self.assertTrue(wrapper.set_running_or_notify_cancel())

        with self.assertRaises(RuntimeError):
            wrapper.cancel()

        self.assertTrue(underlying.cancelled())
        self.assertFalse(wrapper.done())


if __name__ == "__main__":
    unittest.main()
