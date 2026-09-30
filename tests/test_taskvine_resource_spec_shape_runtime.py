"""Runtime probe for TaskVine resource-specification type validation."""

import unittest

from parsl.executors.taskvine.executor import TaskVineExecutor


class TaskVineResourceSpecShapeRuntimeTest(unittest.TestCase):
    def test_non_mapping_spec_exposes_attribute_error_currently(self):
        executor = TaskVineExecutor.__new__(TaskVineExecutor)
        with self.assertRaises(AttributeError):
            executor.submit(lambda: None, [])


if __name__ == "__main__":
    unittest.main()
