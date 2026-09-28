"""Runtime probe for falsey exceptions in DataFuture parent propagation."""

import unittest
from concurrent.futures import Future

from parsl.app.futures import DataFuture
from parsl.data_provider.files import File


class FalseyError(Exception):
    def __bool__(self):
        return False


class DataFutureFalseyExceptionRuntimeTest(unittest.TestCase):
    def test_falsey_parent_exception_is_mistaken_for_success_currently(self):
        parent = Future()
        data_future = DataFuture(parent, File("/tmp/falsey-output"), tid=1)
        error = FalseyError("deliberate falsey failure")
        parent.set_exception(error)

        self.assertTrue(data_future.done())
        self.assertIsNone(data_future.exception())
        self.assertEqual(data_future.result().filepath, "/tmp/falsey-output")


if __name__ == "__main__":
    unittest.main()
