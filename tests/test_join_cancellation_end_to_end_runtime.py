"""End-to-end runtime bridge for a cancelled inner join Future."""

import unittest
from concurrent.futures import Future, TimeoutError

import parsl
from parsl import Config, join_app
from parsl.executors.threads import ThreadPoolExecutor


@join_app
def return_cancelled_inner():
    inner = Future()
    inner.cancel()
    return inner


class JoinCancellationEndToEndRuntimeTest(unittest.TestCase):
    def test_cancelled_inner_leaves_outer_joining_currently(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=1)])
        with parsl.load(config):
            outer = return_cancelled_inner()
            with self.assertRaises(TimeoutError):
                outer.result(timeout=0.2)
            self.assertFalse(outer.done())


if __name__ == "__main__":
    unittest.main()
