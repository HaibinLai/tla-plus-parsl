"""Runtime probe for unhashable callable objects in ParslPoolExecutor."""

import unittest

from parsl.concurrent import ParslPoolExecutor


class UnhashableCallable:
    __hash__ = None

    def __call__(self, value):
        return value + 1


class PoolExecutorCallableCacheRuntimeTest(unittest.TestCase):
    def test_unhashable_callable_fails_cache_lookup_currently(self):
        pool = ParslPoolExecutor.__new__(ParslPoolExecutor)
        pool._app_cache = {}
        callable_obj = UnhashableCallable()

        with self.assertRaises(TypeError):
            pool.get_app(callable_obj)


if __name__ == "__main__":
    unittest.main()
