"""Runtime probes for AutoCancelTimer cleanup around Python app execution."""

import time
import unittest

from parsl.app.errors import AppTimeout
from parsl.app.python import timeout


class TimeoutTimerRuntimeTest(unittest.TestCase):
    def test_fast_return_cancels_timer(self):
        wrapped = timeout(lambda: "done", 0.05)

        self.assertEqual(wrapped(), "done")
        time.sleep(0.1)

    def test_regular_function_exception_cancels_timer(self):
        def raises():
            raise ValueError("ordinary failure")

        wrapped = timeout(raises, 0.05)
        with self.assertRaises(ValueError):
            wrapped()

        time.sleep(0.1)
        # If the timer were not cancelled, this sleep could receive a delayed
        # AppTimeout in the current thread.
        self.assertTrue(True)

    def test_slow_function_receives_app_timeout(self):
        def slow():
            time.sleep(0.2)

        with self.assertRaises(AppTimeout):
            timeout(slow, 0.01)()


if __name__ == "__main__":
    unittest.main()
