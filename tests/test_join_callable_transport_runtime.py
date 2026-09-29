"""Runtime bridge for join_app ordering over serialized inner apps."""

import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def add_offset(value, payload):
    return value + payload["offset"]


@join_app
def join_serialized_values(first, second):
    first_future = add_offset(10, first)
    second_future = add_offset(10, second)
    return [first_future, second_future, first_future]


class JoinCallableTransportRuntimeTest(unittest.TestCase):
    def test_join_preserves_serialized_values_and_duplicate_positions(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)])
        with parsl.load(config):
            result = join_serialized_values({"offset": 1}, {"offset": 2})
            self.assertEqual(result.result(), [11, 12, 11])
            self.assertIsNone(result.exception())


if __name__ == "__main__":
    unittest.main()
