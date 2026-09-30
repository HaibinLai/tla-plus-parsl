"""Runtime probe for Work Queue resource-specification validation order."""

import tempfile
import threading
import unittest
from pathlib import Path

from parsl.executors.workqueue.executor import WorkQueueExecutor


class WorkQueueResourceSpecShapeRuntimeTest(unittest.TestCase):
    def test_non_mapping_spec_creates_task_directory_before_assertion_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = WorkQueueExecutor.__new__(WorkQueueExecutor)
            provider.executor_task_counter = 0
            provider.function_data_dir = directory
            provider._tasks = {}
            provider.tasks_lock = threading.Lock()

            with self.assertRaises(AssertionError):
                provider.submit(lambda: None, [])

            self.assertTrue((Path(directory) / "0001").is_dir())
            self.assertEqual(provider.tasks, {})


if __name__ == "__main__":
    unittest.main()
