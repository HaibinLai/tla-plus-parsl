"""Runtime probe for DataFuture propagation of a cancelled parent Future."""

import unittest
from concurrent.futures import Future

from parsl.app.futures import DataFuture
from parsl.data_provider.files import File


class DataFutureCancellationRuntimeTest(unittest.TestCase):
    def test_cancelled_parent_is_currently_published_as_available(self):
        parent = Future()
        data_future = DataFuture(parent, File("/tmp/cancelled-output"), tid=1)

        self.assertTrue(parent.cancel())
        self.assertTrue(data_future.done())
        self.assertFalse(data_future.cancelled())
        self.assertEqual(data_future.result().filepath, "/tmp/cancelled-output")

    def test_failed_parent_propagates_failure(self):
        parent = Future()
        data_future = DataFuture(parent, File("/tmp/failed-output"), tid=2)

        parent.set_exception(RuntimeError("producer failed"))
        with self.assertRaises(RuntimeError):
            data_future.result()


if __name__ == "__main__":
    unittest.main()
