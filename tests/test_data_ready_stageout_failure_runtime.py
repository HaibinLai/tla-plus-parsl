import os
import tempfile
import unittest
from concurrent.futures import Future

from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File
from parsl.dataflow.futures import DataFuture


class IndependentStageOut:
    def can_stage_out(self, file_obj):
        return True

    def stage_out(self, dm, executor, file_obj, app_future):
        transfer = Future()
        transfer.set_result("published")
        return transfer


class DataReadyStageOutFailureRuntimeTest(unittest.TestCase):
    def test_independent_transfer_can_ready_datafuture_after_app_failure_currently(self):
        with tempfile.TemporaryDirectory() as workdir:
            path = os.path.join(workdir, "output.bin")
            with open(path, "wb") as stream:
                stream.write(b"chunk-0chunk-1")

            provider = IndependentStageOut()
            executor = type("Executor", (), {"storage_access": [provider]})()
            dfk = type("DFK", (), {"executors": {"exec": executor}})()
            manager = DataManager(dfk)
            app = Future()
            app.set_exception(RuntimeError("application failed"))
            transfer = manager.stage_out(File("file://" + path), "exec", app)
            data_future = DataFuture(transfer, File("file://" + path), tid=7)

            self.assertTrue(data_future.done())
            self.assertEqual(data_future.result().filepath, path)
            self.assertIsInstance(app.exception(), RuntimeError)


if __name__ == "__main__":
    unittest.main()
