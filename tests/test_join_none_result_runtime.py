"""Runtime probes for None-valued join_app results."""

import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def return_none():
    return None


@join_app
def join_single_none():
    return return_none()


@join_app
def join_list_none():
    return [return_none(), return_none()]


class JoinNoneResultRuntimeTest(unittest.TestCase):
    def test_single_none_is_a_successful_result(self):
        with parsl.load(Config(executors=[ThreadPoolExecutor(max_threads=2)])):
            result = join_single_none()
            self.assertIsNone(result.result())
            self.assertTrue(result.done())
            self.assertIsNone(result.exception())

    def test_list_preserves_none_values_and_positions(self):
        with parsl.load(Config(executors=[ThreadPoolExecutor(max_threads=2)])):
            result = join_list_none()
            self.assertEqual(result.result(), [None, None])
            self.assertTrue(result.done())
            self.assertIsNone(result.exception())


if __name__ == "__main__":
    unittest.main()
