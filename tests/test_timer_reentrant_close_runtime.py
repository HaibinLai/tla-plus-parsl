"""Runtime probe for Timer.close called from its own callback."""

import threading
import unittest

from parsl.utils import Timer


class TimerReentrantCloseRuntimeTest(unittest.TestCase):
    def test_callback_close_attempt_hits_current_thread_join_error_currently(self):
        entered = threading.Event()
        proceed = threading.Event()
        errors = []
        holder = {}

        def callback():
            entered.set()
            proceed.wait(timeout=1)
            try:
                holder["timer"].close(timeout=0.01)
            except RuntimeError as exc:
                errors.append(exc)

        timer = Timer(callback, interval=60, name="runtime-reentrant-close")
        holder["timer"] = timer
        try:
            self.assertTrue(entered.wait(timeout=1))
            proceed.set()
            timer._thread.join(timeout=1)
            self.assertEqual(len(errors), 1)
            self.assertIn("cannot join current thread", str(errors[0]))
        finally:
            timer.close(timeout=1)


if __name__ == "__main__":
    unittest.main()
