"""Runtime bridge for retrying a join_app body before joining an inner Future."""

import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.executors.threads import ThreadPoolExecutor


attempts = {"body": 0}


@python_app
def join_body_inner_value():
    return "inner-result"


@join_app
def retrying_join_body():
    attempts["body"] += 1
    if attempts["body"] == 1:
        raise RuntimeError("join body transient failure")
    return join_body_inner_value()


class JoinBodyRetryRuntimeTest(unittest.TestCase):
    def test_join_body_retry_installs_join_only_after_success(self):
        attempts["body"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)], retries=1)

        with parsl.load(config):
            self.assertEqual(retrying_join_body().result(), "inner-result")

        self.assertEqual(attempts["body"], 2)


if __name__ == "__main__":
    unittest.main()
