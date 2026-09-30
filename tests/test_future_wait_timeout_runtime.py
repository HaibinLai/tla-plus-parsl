"""Runtime bridge for caller-side Future.result(timeout=...) semantics."""

import unittest
from concurrent.futures import Future, TimeoutError


class FutureWaitTimeoutRuntimeTest(unittest.TestCase):
    def test_wait_timeout_does_not_cancel_or_reject_future(self):
        future = Future()

        with self.assertRaises(TimeoutError):
            future.result(timeout=0.001)

        self.assertFalse(future.done())
        self.assertFalse(future.cancelled())

        future.set_result("completed-after-wait-timeout")
        self.assertTrue(future.done())
        self.assertEqual(future.result(timeout=0), "completed-after-wait-timeout")


if __name__ == "__main__":
    unittest.main()
