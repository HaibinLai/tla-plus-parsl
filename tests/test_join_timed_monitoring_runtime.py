"""Runtime bridge for an inner walltime timeout through join_app."""

import time
import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.dataflow.errors import JoinError
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def slow_inner():
    time.sleep(0.2)
    return "too-late"


@join_app
def timed_join():
    return slow_inner(walltime=0.01)


class JoinTimedMonitoringRuntimeTest(unittest.TestCase):
    def test_inner_walltime_timeout_becomes_outer_join_error(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)])
        with parsl.load(config):
            outer = timed_join()
            with self.assertRaises(JoinError) as raised:
                outer.result()

        self.assertIn("join", str(raised.exception).lower())
        self.assertTrue(outer.done())


if __name__ == "__main__":
    unittest.main()
