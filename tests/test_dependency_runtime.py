"""Runtime probes for ordinary Future dependency propagation."""

import unittest

import parsl
from parsl import Config, python_app
from parsl.dataflow.errors import DependencyError
from parsl.executors.threads import ThreadPoolExecutor


dependency_calls = {"count": 0}


@python_app
def dependency_source(value):
    return value * 2


@python_app
def dependency_consumer(value):
    dependency_calls["count"] += 1
    return value + 1


@python_app
def dependency_failure():
    raise RuntimeError("upstream failure")


class DependencyRuntimeTest(unittest.TestCase):
    def test_successful_future_result_flows_to_consumer(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)])

        with parsl.load(config):
            source = dependency_source(4)
            consumer = dependency_consumer(source)

            self.assertEqual(source.result(), 8)
            self.assertEqual(consumer.result(), 9)

    def test_failed_future_blocks_consumer_execution(self):
        dependency_calls["count"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)])

        with parsl.load(config):
            source = dependency_failure()
            consumer = dependency_consumer(source)

            self.assertIsInstance(source.exception(), RuntimeError)
            self.assertIsInstance(consumer.exception(), DependencyError)

        self.assertEqual(dependency_calls["count"], 0)


if __name__ == "__main__":
    unittest.main()
