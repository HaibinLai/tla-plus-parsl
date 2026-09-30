"""Runtime probe for the unsupported outer join Future cancellation path."""

import unittest
from concurrent.futures import Future

import parsl
from parsl import Config, join_app
from parsl.executors.threads import ThreadPoolExecutor


@join_app
def return_pending_inner():
    return Future()


class OuterJoinCancellationRuntimeTest(unittest.TestCase):
    def test_outer_cancel_is_not_implemented_currently(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=1)])
        with parsl.load(config):
            outer = return_pending_inner()
            with self.assertRaises(NotImplementedError):
                outer.cancel()
            self.assertFalse(outer.cancelled())
            self.assertFalse(outer.done())


if __name__ == "__main__":
    unittest.main()
