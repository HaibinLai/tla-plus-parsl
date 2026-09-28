"""Runtime probes for the concrete Parsl join_app callback protocol."""

import unittest
from concurrent.futures import Future

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


@join_app
def join_invalid_return():
    return 3


@join_app
def join_mixed_list():
    return [join_value(4), 5]


@join_app
def join_nested_inner():
    return join_value(6)


@join_app
def join_nested_outer():
    return join_nested_inner()


@join_app
def join_precompleted():
    inner = Future()
    inner.set_result(9)
    return inner


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

            self.assertEqual(join_nested_outer().result(), 6)

            invalid = join_invalid_return()
            self.assertIsInstance(invalid.exception(), TypeError)

            mixed = join_mixed_list()
            self.assertIsInstance(mixed.exception(), TypeError)

    def test_already_completed_inner_future_callback(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)])
        with parsl.load(config):
            self.assertEqual(join_precompleted().result(), 9)


if __name__ == "__main__":
    unittest.main()
