"""Runtime probe for join_app return validation invoking user equality."""

import unittest
from concurrent.futures import TimeoutError

import parsl
from parsl import Config, join_app
from parsl.executors.threads import ThreadPoolExecutor


class ExplosiveEquality:
    def __eq__(self, other):
        raise RuntimeError("user equality should not run during join validation")


@join_app
def join_explosive_return():
    return ExplosiveEquality()


class JoinReturnEqualityRuntimeTest(unittest.TestCase):
    def test_equality_exception_leaves_outer_future_pending_currently(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)])
        with parsl.load(config):
            result = join_explosive_return()
            with self.assertRaises(TimeoutError):
                result.result(timeout=1)
            self.assertFalse(result.done())


if __name__ == "__main__":
    unittest.main()
