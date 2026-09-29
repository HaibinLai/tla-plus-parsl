"""Runtime probe for Flux wrapper cancellation state propagation."""

import unittest

from parsl.executors.flux.executor import FluxFutureWrapper


class AlreadyCancelledFluxFuture:
    def cancelled(self):
        return True


class FluxCancelUnderlyingStateRuntimeTest(unittest.TestCase):
    def test_already_cancelled_underlying_future_leaves_wrapper_pending_currently(self):
        wrapper = FluxFutureWrapper()
        wrapper._flux_future = AlreadyCancelledFluxFuture()

        self.assertTrue(wrapper.cancel())
        self.assertFalse(wrapper.done())
        self.assertFalse(wrapper.cancelled())


if __name__ == "__main__":
    unittest.main()
