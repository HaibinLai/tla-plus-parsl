"""Runtime bridge for map timeout followed by advisory shutdown."""

import unittest
from concurrent.futures import Future, TimeoutError

from parsl.concurrent import ParslPoolExecutor


class PoolExecutorMapShutdownRuntimeTest(unittest.TestCase):
    def test_timeout_then_shutdown_does_not_cancel_submitted_future(self):
        pending = Future()
        ready = Future()
        ready.set_result("ready")

        pool = ParslPoolExecutor.__new__(ParslPoolExecutor)
        pool._dfk = object()
        pool._config = None
        pool.executors = "all"
        pool._app_cache = {}
        pool.get_app = lambda fn: (lambda *args: pending if args[0] == 1 else ready)

        values = pool.map(lambda value: value, [1, 2], timeout=0)
        with self.assertRaises(TimeoutError):
            next(values)
        with self.assertWarns(UserWarning):
            pool.shutdown(wait=False, cancel_futures=True)

        self.assertFalse(pending.cancelled())
        pending.set_result("late")
        self.assertEqual(pending.result(), "late")


if __name__ == "__main__":
    unittest.main()
