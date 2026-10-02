"""Runtime bridge for ThreadPoolExecutor shutdown(wait=False)."""

import threading
import unittest

from parsl.executors.threads import ThreadPoolExecutor


class ThreadExecutorNonblockingShutdownRuntimeTest(unittest.TestCase):
    def test_nonblocking_shutdown_keeps_running_callable_alive(self):
        started = threading.Event()
        release = threading.Event()

        def blocked():
            started.set()
            release.wait(timeout=5)
            return "done"

        executor = ThreadPoolExecutor(max_threads=1)
        executor.start()
        try:
            future = executor.submit(blocked, {})
            self.assertTrue(started.wait(timeout=5))
            executor.shutdown(block=False)
            self.assertFalse(future.done())
            release.set()
            self.assertEqual(future.result(timeout=5), "done")
        finally:
            release.set()


if __name__ == "__main__":
    unittest.main()
