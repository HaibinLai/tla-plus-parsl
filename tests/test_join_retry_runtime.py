"""Runtime probe for join_app waiting on an inner Future's physical retry."""

import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.executors.threads import ThreadPoolExecutor


inner_attempts = {"count": 0}


@python_app
def flaky_inner():
    inner_attempts["count"] += 1
    if inner_attempts["count"] == 1:
        raise RuntimeError("first physical attempt")
    return "inner-success"


@join_app
def join_after_retry():
    return flaky_inner()


class JoinRetryRuntimeTest(unittest.TestCase):
    def test_join_waits_for_retry_and_returns_final_inner_value(self):
        inner_attempts["count"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)], retries=1)

        with parsl.load(config):
            outer = join_after_retry()
            self.assertEqual(outer.result(), "inner-success")

        self.assertEqual(inner_attempts["count"], 2)


if __name__ == "__main__":
    unittest.main()
