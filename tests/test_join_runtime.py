"""Runtime probes for the concrete Parsl join_app callback protocol."""

import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.dataflow.errors import JoinError
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def join_value(value):
    return value


@python_app
def join_failure():
    raise RuntimeError("inner failure")


@join_app
def join_single():
    return join_value(3)


@join_app
def join_ordered_duplicates():
    first = join_value(1)
    return [join_value(2), first, first]


@join_app
def join_empty():
    return []


@join_app
def join_failed():
    return join_failure()


class JoinRuntimeTest(unittest.TestCase):
    def test_single_ordered_duplicate_empty_and_failure_semantics(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)])
        with parsl.load(config):
            self.assertEqual(join_single().result(), 3)
            self.assertEqual(join_ordered_duplicates().result(), [2, 1, 1])
            self.assertEqual(join_empty().result(), [])

            failed = join_failed()
            exception = failed.exception()
            self.assertIsInstance(exception, JoinError)
            self.assertEqual(len(exception.dependent_exceptions_tids), 1)
            self.assertIsInstance(exception.dependent_exceptions_tids[0][0], RuntimeError)


if __name__ == "__main__":
    unittest.main()
