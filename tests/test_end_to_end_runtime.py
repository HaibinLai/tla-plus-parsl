"""Runtime probe for rejecting a late result from a timed-out physical attempt."""

import time
import unittest

import parsl
from parsl import Config, python_app
from parsl.executors.threads import ThreadPoolExecutor


attempts = {"count": 0}


@python_app
def late_first_attempt(walltime=None):
    attempts["count"] += 1
    if attempts["count"] == 1:
        # The walltime timer causes a retry, but this physical attempt keeps
        # running long enough to return a late value afterwards.
        time.sleep(0.1)
        return "late"
    return "fresh"


class EndToEndRuntimeTest(unittest.TestCase):
    def test_late_timed_out_attempt_does_not_resolve_future(self):
        attempts["count"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)], retries=1)

        with parsl.load(config):
            future = late_first_attempt(walltime=0.01)
            self.assertEqual(future.result(timeout=2), "fresh")
            # Allow the first worker to return after the logical Future has
            # already been resolved by the retry.
            time.sleep(0.15)
            self.assertIsNone(future.exception())

        self.assertEqual(attempts["count"], 2)


if __name__ == "__main__":
    unittest.main()
