"""Runtime probe for executor context-manager exception preservation."""

import unittest

from parsl.executors.base import ParslExecutor


class FailingShutdownExecutor(ParslExecutor):
    def submit(self, func, resource_specification, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self):
        raise RuntimeError("shutdown failed")


class ExecutorContextExitRuntimeTest(unittest.TestCase):
    def test_shutdown_error_masks_body_error_currently(self):
        with self.assertRaisesRegex(RuntimeError, "shutdown failed") as caught:
            with FailingShutdownExecutor():
                raise ValueError("body failed")

        self.assertIsInstance(caught.exception.__context__, ValueError)


if __name__ == "__main__":
    unittest.main()
