"""Runtime probes for parsl.utils.Timer callback and close semantics."""

import threading
import time
import unittest

from parsl.utils import Timer


class PeriodicTimerRuntimeTest(unittest.TestCase):
    def test_callback_exception_does_not_stop_periodic_timer(self):
        calls = []
        done = threading.Event()

        def callback():
            calls.append(len(calls))
            if len(calls) == 1:
                raise RuntimeError("first callback failure")
            if len(calls) >= 3:
                done.set()

        timer = Timer(callback, interval=0.01, name="runtime-periodic")
        try:
            self.assertTrue(done.wait(1.0))
            self.assertGreaterEqual(len(calls), 3)
        finally:
            timer.close(timeout=1.0)

    def test_close_stops_future_callbacks(self):
        calls = []
        timer = Timer(lambda: calls.append(time.monotonic()), interval=0.01,
                      name="runtime-close")
        time.sleep(0.04)
        timer.close(timeout=1.0)
        count_at_close = len(calls)
        time.sleep(0.04)
        self.assertEqual(len(calls), count_at_close)


if __name__ == "__main__":
    unittest.main()
