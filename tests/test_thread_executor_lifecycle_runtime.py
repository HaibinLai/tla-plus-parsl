"""Runtime bridge for ThreadPoolExecutor failed-start cleanup."""

import unittest

from parsl.executors.threads import ThreadPoolExecutor


class ThreadExecutorLifecycleRuntimeTest(unittest.TestCase):
    def test_failed_start_leaves_shutdown_with_raw_attribute_error_currently(self):
        executor = ThreadPoolExecutor(max_threads=0)
        with self.assertRaises(ValueError):
            executor.start()

        with self.assertRaises(AttributeError):
            executor.shutdown()


if __name__ == "__main__":
    unittest.main()
