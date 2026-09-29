"""Runtime probes for ParslPoolExecutor.map timeout semantics."""

import unittest
from concurrent.futures import Future, TimeoutError

from parsl.concurrent import ParslPoolExecutor


class PoolExecutorMapRuntimeTest(unittest.TestCase):
    def test_timeout_does_not_cancel_submitted_futures(self):
        first = Future()
        second = Future()
        second.set_result("second")

        pool = ParslPoolExecutor.__new__(ParslPoolExecutor)
        pool._dfk = object()
        pool._config = None
        pool.executors = "all"
        pool._app_cache = {}
        pool.get_app = lambda fn: (lambda *args: first if args[0] == 1 else second)

        values = pool.map(lambda value: value, [1, 2], timeout=0)
        with self.assertRaises(TimeoutError):
            next(values)

        self.assertFalse(first.cancelled())
        self.assertFalse(second.cancelled())

    def test_shutdown_cancel_futures_is_advisory(self):
        pool = ParslPoolExecutor.__new__(ParslPoolExecutor)
        pool._dfk = object()
        pool._config = None

        with self.assertWarns(UserWarning):
            pool.shutdown(wait=False, cancel_futures=True)
        self.assertIsNone(pool._dfk)


if __name__ == "__main__":
    unittest.main()
