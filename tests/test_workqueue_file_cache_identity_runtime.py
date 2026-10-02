"""Runtime probe for Work Queue's File-object cache identity boundary."""

import unittest

from parsl.data_provider.files import File
from parsl.executors.workqueue.executor import WorkQueueExecutor


class WorkQueueFileCacheIdentityRuntimeTest(unittest.TestCase):
    def test_distinct_file_objects_with_same_path_miss_cache_currently(self):
        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
        executor.use_cache = True
        executor.registered_files = set()

        first = executor._register_file(File("input.dat"))
        second = executor._register_file(File("input.dat"))

        self.assertEqual(first.parsl_name, second.parsl_name)
        self.assertFalse(first.cache)
        self.assertFalse(second.cache)


if __name__ == "__main__":
    unittest.main()
