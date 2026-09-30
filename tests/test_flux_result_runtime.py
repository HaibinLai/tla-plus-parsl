"""Runtime probes for Flux result callbacks and wrapper cancellation."""

import tempfile
import unittest
from concurrent.futures import InvalidStateError
from pathlib import Path

from parsl.app.errors import AppException
from parsl.executors.flux import TaskResult
from parsl.executors.flux.executor import FluxFutureWrapper, _complete_future
from parsl.serialize import serialize


class FakeFluxFuture:
    def __init__(self, return_code=0, cancelled=False, cancel_result=True):
        self.return_code = return_code
        self._cancelled = cancelled
        self.cancel_result = cancel_result

    def cancelled(self):
        return self._cancelled

    def result(self):
        return self.return_code

    def cancel(self):
        self._cancelled = True
        return self.cancel_result

    def running(self):
        return not self._cancelled


class FluxResultRuntimeTest(unittest.TestCase):
    def run_callback(self, payload, return_code=0):
        with tempfile.TemporaryDirectory() as directory:
            result_path = Path(directory) / "result.pkl"
            if payload is not None:
                result_path.write_bytes(payload)
            wrapper = FluxFutureWrapper()
            _complete_future(str(result_path), wrapper, FakeFluxFuture(return_code=return_code))
            return wrapper

    def test_valid_result_file_resolves_wrapper(self):
        wrapper = self.run_callback(serialize(TaskResult("answer", None)))

        self.assertEqual(wrapper.result(), "answer")

    def test_task_exception_in_result_file_fails_wrapper(self):
        wrapper = self.run_callback(serialize(TaskResult(None, ValueError("bad app"))))

        with self.assertRaises(ValueError):
            wrapper.result()

    def test_missing_result_file_fails_wrapper(self):
        wrapper = self.run_callback(None)

        with self.assertRaises(FileNotFoundError):
            wrapper.result()

    def test_nonzero_flux_exit_fails_with_app_exception(self):
        wrapper = self.run_callback(None, return_code=7)

        with self.assertRaises(AppException):
            wrapper.result()

    def test_cancelled_flux_callback_leaves_wrapper_pending_currently(self):
        wrapper = FluxFutureWrapper()
        _complete_future("unused", wrapper, FakeFluxFuture(cancelled=True))

        self.assertFalse(wrapper.done())

    def test_wrapper_cancel_propagates_to_underlying_future(self):
        wrapper = FluxFutureWrapper()
        flux_future = FakeFluxFuture()
        wrapper._flux_future = flux_future

        self.assertTrue(wrapper.cancel())
        self.assertTrue(flux_future.cancelled())
        self.assertTrue(wrapper.cancelled())

    def test_late_success_result_writes_cancelled_wrapper_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            result_path = Path(directory) / "result.pkl"
            result_path.write_bytes(serialize(TaskResult("late", None)))
            wrapper = FluxFutureWrapper()
            self.assertTrue(wrapper.cancel())

            with self.assertRaises(InvalidStateError):
                _complete_future(str(result_path), wrapper, FakeFluxFuture())

            self.assertTrue(wrapper.cancelled())


if __name__ == "__main__":
    unittest.main()
