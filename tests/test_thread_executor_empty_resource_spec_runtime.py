"""Runtime probe for empty non-mapping resource-specification admission."""

import unittest

from parsl.executors.threads import ThreadPoolExecutor


class ThreadExecutorEmptyResourceSpecRuntimeTest(unittest.TestCase):
    def test_empty_list_resource_spec_is_accepted_currently(self):
        executor = ThreadPoolExecutor(max_threads=1)
        executor.start()
        try:
            future = executor.submit(lambda: 7, [])
            self.assertEqual(future.result(timeout=2), 7)
        finally:
            executor.shutdown()


if __name__ == "__main__":
    unittest.main()
