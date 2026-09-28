"""Runtime probe for DataManager stage-out callback ordering."""

import unittest
from concurrent.futures import Future
from types import SimpleNamespace

from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File


class FailingStageOutWrapperProvider:
    def __init__(self):
        self.stage_future = Future()

    def can_stage_out(self, file):
        return True

    def stage_out(self, dm, executor, file, app_fu):
        # A separate stage-out provider can return a pending transfer Future.
        return self.stage_future

    def replace_task_stage_out(self, dm, executor, file, func):
        raise RuntimeError("stage-out wrapper construction failed")


class DataManagerStageOutOrderingRuntimeTest(unittest.TestCase):
    def test_wrapper_failure_leaves_started_stage_out_future_currently(self):
        provider = FailingStageOutWrapperProvider()
        dfk = SimpleNamespace(
            executors={"fake": SimpleNamespace(storage_access=[provider])}
        )
        manager = DataManager(dfk)

        with self.assertRaisesRegex(RuntimeError, "stage-out wrapper construction failed"):
            manager.stage_out(
                File("zip:/tmp/results.zip/output.bin"),
                "fake",
                Future(),
            )
            # The normal DFK path calls this immediately after stage_out.
            manager.replace_task_stage_out(
                File("zip:/tmp/results.zip/output.bin"),
                lambda: None,
                "fake",
            )

        self.assertFalse(provider.stage_future.done())
        self.assertFalse(provider.stage_future.cancelled())


if __name__ == "__main__":
    unittest.main()
