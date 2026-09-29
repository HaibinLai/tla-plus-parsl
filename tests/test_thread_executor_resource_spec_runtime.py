"""Runtime probe for ThreadPoolExecutor resource-specification validation."""

import unittest

from parsl.executors.errors import InvalidResourceSpecification
from parsl.executors.threads import ThreadPoolExecutor


class ThreadExecutorResourceSpecRuntimeTest(unittest.TestCase):
    def test_truthy_non_mapping_raises_attribute_error_currently(self):
        executor = ThreadPoolExecutor(max_threads=1)
        executor.start()
        try:
            with self.assertRaises(AttributeError):
                executor.submit(lambda: 1, ["cores"])
        finally:
            executor.shutdown(block=True)

    def test_mapping_is_rejected_with_controlled_error(self):
        executor = ThreadPoolExecutor(max_threads=1)
        executor.start()
        try:
            with self.assertRaises(InvalidResourceSpecification):
                executor.submit(lambda: 1, {"cores": 1})
        finally:
            executor.shutdown(block=True)


if __name__ == "__main__":
    unittest.main()
