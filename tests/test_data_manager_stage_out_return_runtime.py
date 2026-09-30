"""Runtime bridge for DataManager.stage_out's None/Future contract."""

import unittest
from concurrent.futures import Future
from types import SimpleNamespace

from parsl.app.futures import DataFuture
from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File


class ReturnShapeProvider:
    def __init__(self, transfer_future):
        self.transfer_future = transfer_future

    def can_stage_out(self, file):
        return True

    def stage_out(self, dm, executor, file, app_future):
        return self.transfer_future


class DataManagerStageOutReturnRuntimeTest(unittest.TestCase):
    def _manager(self, provider):
        return DataManager(SimpleNamespace(
            executors={"fake": SimpleNamespace(storage_access=[provider])}
        ))

    def test_none_return_follows_application_future(self):
        provider = ReturnShapeProvider(None)
        manager = self._manager(provider)
        app_future = Future()
        result = manager.stage_out(File("noop:/tmp/result"), "fake", app_future)

        self.assertIsNone(result)
        output = DataFuture(app_future, File("noop:/tmp/result"), tid=1)
        self.assertFalse(output.done())
        app_future.set_result("complete")
        self.assertTrue(output.done())
        self.assertEqual(output.result().url, "noop:/tmp/result")
        self.assertEqual(app_future.result(), "complete")

    def test_future_return_is_independent_transfer_dependency(self):
        transfer_future = Future()
        provider = ReturnShapeProvider(transfer_future)
        manager = self._manager(provider)
        app_future = Future()
        result = manager.stage_out(File("noop:/tmp/result"), "fake", app_future)

        self.assertIs(result, transfer_future)
        output = DataFuture(result, File("noop:/tmp/result"), tid=2)
        app_future.set_result("application-complete")
        self.assertFalse(output.done())
        transfer_future.set_result("transfer-complete")
        self.assertTrue(output.done())
        self.assertEqual(output.result().url, "noop:/tmp/result")
        self.assertEqual(transfer_future.result(), "transfer-complete")


if __name__ == "__main__":
    unittest.main()
