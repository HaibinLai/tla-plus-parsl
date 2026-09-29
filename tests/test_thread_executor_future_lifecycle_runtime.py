"""Runtime bridge for ThreadPoolExecutor Future cancellation semantics."""

import threading
import unittest

from parsl.executors.threads import ThreadPoolExecutor


class ThreadExecutorFutureLifecycleRuntimeTest(unittest.TestCase):
    def test_pending_future_cancels_but_running_future_does_not(self):
        started = threading.Event()
        release = threading.Event()

        def blocked():
            started.set()
            release.wait(timeout=5)
            return "done"

        executor = ThreadPoolExecutor(max_threads=1)
        executor.start()
        try:
            running = executor.submit(blocked, {})
            self.assertTrue(started.wait(timeout=5))
            pending = executor.submit(lambda: "never-started", {})

            self.assertFalse(running.cancel())
            self.assertTrue(pending.cancel())
            release.set()
            self.assertEqual(running.result(timeout=5), "done")
            self.assertTrue(pending.cancelled())
        finally:
            release.set()
            executor.shutdown()


if __name__ == "__main__":
    unittest.main()
