"""Runtime probes for Parsl BasicMemoizer and cached Future dependencies."""

import unittest

import parsl
from parsl import Config, python_app
from parsl.executors.threads import ThreadPoolExecutor


memo_calls = {"count": 0}


@python_app(cache=True)
def memoized_double(value):
    memo_calls["count"] += 1
    return value * 2


@python_app
def add_one(value):
    return value + 1


class MemoizationRuntimeTest(unittest.TestCase):
    def test_duplicate_call_is_cached_and_dependency_can_consume_it(self):
        memo_calls["count"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)])

        with parsl.load(config):
            first = memoized_double(3)
            duplicate = memoized_double(3)
            different = memoized_double(4)
            dependent = add_one(memoized_double(3))

            self.assertEqual(first.result(), 6)
            self.assertEqual(duplicate.result(), 6)
            self.assertEqual(different.result(), 8)
            self.assertEqual(dependent.result(), 7)

        self.assertEqual(memo_calls["count"], 2)


if __name__ == "__main__":
    unittest.main()
