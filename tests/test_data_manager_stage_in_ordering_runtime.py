"""Runtime probe for DataManager stage-in callback ordering."""

import unittest
from concurrent.futures import Future
from types import SimpleNamespace

from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File


class FailingWrapperProvider:
    def __init__(self):
        self.stage_future = Future()

    def can_stage_in(self, file):
        return True

    def stage_in(self, dm, executor, file, parent_fut):
        # A real separate-task provider can return a still-running Future here.
        return self.stage_future

    def replace_task(self, dm, executor, file, func):
        raise RuntimeError("wrapper construction failed")


class DataManagerStageInOrderingRuntimeTest(unittest.TestCase):
    def test_wrapper_failure_leaves_started_stage_in_future_currently(self):
        provider = FailingWrapperProvider()
        dfk = SimpleNamespace(
            executors={"fake": SimpleNamespace(storage_access=[provider])}
        )
        manager = DataManager(dfk)

        with self.assertRaisesRegex(RuntimeError, "wrapper construction failed"):
            manager.optionally_stage_in(
                File("ftp://example.test/input.bin"),
                lambda value: value,
                "fake",
            )

        # DataManager has no cleanup/rollback hook after replace_task raises;
        # the transfer returned by stage_in is still pending.
        self.assertFalse(provider.stage_future.done())
        self.assertFalse(provider.stage_future.cancelled())


if __name__ == "__main__":
    unittest.main()
