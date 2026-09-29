"""Runtime probes for nested join_app result and failure propagation."""

import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.dataflow.errors import JoinError
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def nested_leaf(value):
    return value


@python_app
def nested_failed_leaf():
    raise ValueError("nested leaf failure")


@join_app
def inner_join_success():
    return [nested_leaf("left"), nested_leaf("right")]


@join_app
def outer_join_success():
    return inner_join_success()


@join_app
def inner_join_failure():
    return nested_failed_leaf()


@join_app
def outer_join_failure():
    return inner_join_failure()


class NestedJoinRuntimeTest(unittest.TestCase):
    def test_nested_join_preserves_inner_order(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=3)])
        with parsl.load(config):
            self.assertEqual(outer_join_success().result(), ["left", "right"])

    def test_nested_join_propagates_leaf_failure(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=3)])
        with parsl.load(config):
            result = outer_join_failure()
            exception = result.exception()
            self.assertIsInstance(exception, JoinError)
            self.assertTrue(exception.dependent_exceptions_tids)
            nested_exception = exception.dependent_exceptions_tids[0][0]
            self.assertIsInstance(nested_exception, JoinError)
            self.assertIsInstance(nested_exception.dependent_exceptions_tids[0][0], ValueError)


if __name__ == "__main__":
    unittest.main()
