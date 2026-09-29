"""End-to-end runtime bridge for list-valued join cancellation."""

import unittest
from concurrent.futures import Future, TimeoutError

import parsl
from parsl import Config, join_app
from parsl.executors.threads import ThreadPoolExecutor


@join_app
def return_success_and_cancelled():
    successful = Future()
    successful.set_result("ok")
    cancelled = Future()
    cancelled.cancel()
    return [successful, cancelled]


class JoinListCancellationEndToEndRuntimeTest(unittest.TestCase):
    def test_cancelled_list_member_leaves_outer_joining_currently(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=1)])
        with parsl.load(config):
            outer = return_success_and_cancelled()
            with self.assertRaises(TimeoutError):
                outer.result(timeout=0.2)
            self.assertFalse(outer.done())


if __name__ == "__main__":
    unittest.main()
