"""Runtime probe for ordered duplicate join inputs after an inner retry."""

import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.executors.threads import ThreadPoolExecutor


attempts = {"count": 0}


@python_app
def flaky_join_inner():
    attempts["count"] += 1
    if attempts["count"] == 1:
        raise RuntimeError("first attempt failed")
    return "retried-value"


@join_app
def join_duplicate_after_retry():
    inner = flaky_join_inner()
    return [inner, inner, inner]


class JoinRetryDuplicatesRuntimeTest(unittest.TestCase):
    def test_retry_preserves_duplicate_input_positions(self):
        attempts["count"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)], retries=1)

        with parsl.load(config):
            self.assertEqual(
                join_duplicate_after_retry().result(),
                ["retried-value", "retried-value", "retried-value"],
            )

        self.assertEqual(attempts["count"], 2)


if __name__ == "__main__":
    unittest.main()
