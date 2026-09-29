"""Runtime probe for Timer.close returning before a running callback exits."""

import threading
import unittest

from parsl.utils import Timer


class TimerCloseTimeoutRuntimeTest(unittest.TestCase):
    def test_close_timeout_returns_while_callback_thread_is_alive(self):
        entered = threading.Event()
        release = threading.Event()

        def callback():
            entered.set()
            release.wait(timeout=2)

        timer = Timer(callback, interval=60, name="runtime-close-timeout")
        try:
            self.assertTrue(entered.wait(timeout=1))
            self.assertIsNone(timer.close(timeout=0.01))
            self.assertTrue(timer._thread.is_alive())
        finally:
            release.set()
            timer.close(timeout=1)


if __name__ == "__main__":
    unittest.main()
