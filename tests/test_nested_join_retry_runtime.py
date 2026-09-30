"""Runtime bridge for nested join_app completion across an inner retry."""

import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.executors.threads import ThreadPoolExecutor


nested_retry_attempts = {"count": 0}


@python_app
def flaky_nested_leaf():
    nested_retry_attempts["count"] += 1
    if nested_retry_attempts["count"] == 1:
        raise RuntimeError("first nested leaf attempt")
    return "leaf-after-retry"


@join_app
def nested_retry_inner():
    return [flaky_nested_leaf()]


@join_app
def nested_retry_outer():
    return nested_retry_inner()


class NestedJoinRetryRuntimeTest(unittest.TestCase):
    def test_outer_join_waits_for_inner_retry_and_preserves_shape(self):
        nested_retry_attempts["count"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=3)], retries=1)

        with parsl.load(config):
            outer = nested_retry_outer()
            self.assertEqual(outer.result(), ["leaf-after-retry"])
            self.assertIsNone(outer.exception())

        self.assertEqual(nested_retry_attempts["count"], 2)


if __name__ == "__main__":
    unittest.main()
