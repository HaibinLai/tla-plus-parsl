"""Runtime probe for invalid ThreadPoolExecutor thread counts."""

import unittest

from parsl.executors.threads import ThreadPoolExecutor


class ThreadExecutorThreadCountRuntimeTest(unittest.TestCase):
    def test_zero_max_threads_fails_only_when_started_currently(self):
        executor = ThreadPoolExecutor(max_threads=0)

        with self.assertRaises(ValueError):
            executor.start()


if __name__ == "__main__":
    unittest.main()
