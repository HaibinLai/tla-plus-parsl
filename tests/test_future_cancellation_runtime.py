"""Runtime probes for Parsl and underlying Future cancellation contracts."""

import threading
import time
import unittest
from concurrent.futures import Future

import parsl
from parsl import Config, python_app
from parsl.app.futures import DataFuture
from parsl.data_provider.files import File
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def cancellation_app():
    return "finished"


class FutureCancellationRuntimeTest(unittest.TestCase):
    def test_app_future_cancel_is_explicitly_unsupported(self):
        with parsl.load(Config(executors=[ThreadPoolExecutor(max_threads=1)])):
            future = cancellation_app()
            with self.assertRaises(NotImplementedError):
                future.cancel()
            self.assertEqual(future.result(), "finished")

    def test_data_future_cancel_is_explicitly_unsupported(self):
        parent = Future()
        data_future = DataFuture(parent, File("/tmp/result.bin"), tid=1)

        with self.assertRaises(NotImplementedError):
            data_future.cancel()
        self.assertFalse(data_future.cancelled())
        parent.set_result("ready")
        self.assertTrue(data_future.done())

    def test_underlying_thread_future_can_cancel_queued_work(self):
        executor = ThreadPoolExecutor(max_threads=1)
        executor.start()
        entered = threading.Event()
        release = threading.Event()

        def blocker():
            entered.set()
            release.wait(timeout=5)

        try:
            running = executor.submit(blocker, {},)
            self.assertTrue(entered.wait(timeout=2))
            queued = executor.submit(lambda: "queued", {})
            self.assertTrue(queued.cancel())
            self.assertTrue(queued.cancelled())
            release.set()
            running.result(timeout=2)
        finally:
            release.set()
            executor.shutdown()


if __name__ == "__main__":
    unittest.main()
