import unittest
from concurrent.futures import Future
from types import SimpleNamespace

from parsl.data_provider.files import File
from parsl.data_provider.globus import GlobusStaging


class StageOutFailureGateRuntimeTest(unittest.TestCase):
    def test_globus_stageout_receives_failed_application_future(self):
        provider = GlobusStaging("destination-endpoint")
        app_future = Future()
        app_future.set_exception(RuntimeError("application failed"))
        stage_future = SimpleNamespace(name="stage-out")
        calls = []

        class FakeStageApp:
            def __call__(self, *args, **kwargs):
                calls.append((args, kwargs))
                return stage_future

        provider._globus_stage_out_app = lambda executor, dfk: FakeStageApp()
        dm = SimpleNamespace(dfk=SimpleNamespace(executors={"exec": SimpleNamespace(
            storage_access=[provider], working_dir="/worker")}))
        result = provider.stage_out(dm, "exec", File("globus://src/output.bin"), app_future)

        self.assertIs(result, stage_future)
        self.assertEqual(len(calls), 1)
        self.assertIs(calls[0][0][0], app_future)
        self.assertIsInstance(calls[0][0][0].exception(), RuntimeError)


if __name__ == "__main__":
    unittest.main()
