"""Runtime probe for join_app return-shape admission."""

import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def join_shape_value():
    return 11


@join_app
def join_tuple_shape():
    return (join_shape_value(),)


class JoinReturnShapeRuntimeTest(unittest.TestCase):
    def test_tuple_return_is_rejected_before_join_callbacks(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)])
        with parsl.load(config):
            result = join_tuple_shape()
            self.assertIsInstance(result.exception(), TypeError)


if __name__ == "__main__":
    unittest.main()
