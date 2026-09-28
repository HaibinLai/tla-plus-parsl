"""Runtime probes for Parsl's shallow and deep dependency resolvers."""

import unittest

import parsl
from parsl import Config, python_app
from parsl.dataflow.dependency_resolvers import DEEP_DEPENDENCY_RESOLVER
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def traversal_source(value):
    return value


@python_app
def nested_double(payload):
    return payload[0] * 2


class DependencyTraversalRuntimeTest(unittest.TestCase):
    def test_deep_resolver_waits_and_unwraps_nested_list(self):
        config = Config(
            executors=[ThreadPoolExecutor(max_threads=2)],
            dependency_resolver=DEEP_DEPENDENCY_RESOLVER,
        )

        with parsl.load(config):
            source = traversal_source(5)
            result = nested_double([source])

            self.assertEqual(result.result(), 10)

    def test_default_shallow_resolver_does_not_unwrap_nested_list(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)])

        with parsl.load(config):
            source = traversal_source(5)
            result = nested_double([source])

            # The default policy only recognizes a Future passed directly.
            # A Future hidden in a list reaches the callable unchanged.
            self.assertIsInstance(result.exception(), TypeError)


if __name__ == "__main__":
    unittest.main()
