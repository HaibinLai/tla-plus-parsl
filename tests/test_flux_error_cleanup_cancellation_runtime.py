"""Runtime probe for Flux error cleanup racing with Future cancellation."""

import queue
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.flux.executor import _error_out_jobs


class FluxErrorCleanupCancellationRuntimeTest(unittest.TestCase):
    def test_cancelled_first_future_strands_later_future(self):
        submitted = queue.Queue()
        first = Future()
        second = Future()
        self.assertTrue(first.cancel())
        submitted.put(type("Job", (), {"future": first})())
        submitted.put(type("Job", (), {"future": second})())

        stop_event = threading.Event()
        stop_event.set()
        with self.assertRaises(Exception) as context:
            _error_out_jobs(submitted, stop_event, RuntimeError("Flux failed"))

        self.assertEqual(type(context.exception).__name__, "InvalidStateError")
        self.assertTrue(first.cancelled())
        self.assertFalse(second.done())


if __name__ == "__main__":
    unittest.main()
