"""Runtime probes for Globus staging Future dependency wiring."""

import unittest
from concurrent.futures import Future
from types import SimpleNamespace

from parsl.data_provider.files import File
from parsl.data_provider.globus import GlobusStaging


class FakeDataFlowKernel:
    def __init__(self, provider):
        self.executors = {
            "exec": SimpleNamespace(
                storage_access=[provider],
                working_dir="/worker",
            )
        }


class FakeDataManager:
    def __init__(self, dfk):
        self.dfk = dfk


class FakeStageApp:
    def __init__(self, result):
        self.result = result
        self.calls = []

    def __call__(self, *args, **kwargs):
        self.calls.append((args, kwargs))
        return self.result


class GlobusStagingRuntimeTest(unittest.TestCase):
    def provider_and_file(self):
        provider = GlobusStaging("destination-endpoint")
        dfk = FakeDataFlowKernel(provider)
        dm = FakeDataManager(dfk)
        file_obj = File("globus://source-endpoint/data/input.txt")
        return provider, dm, file_obj

    def test_stage_in_preserves_parent_future_dependency(self):
        provider, dm, file_obj = self.provider_and_file()
        parent = Future()
        staged_output = SimpleNamespace(name="stage-in-output")
        stage_app = FakeStageApp(SimpleNamespace(_outputs=[staged_output]))
        provider._globus_stage_in_app = lambda executor, dfk: stage_app

        result = provider.stage_in(dm, "exec", file_obj, parent)

        self.assertIs(result, staged_output)
        self.assertEqual(len(stage_app.calls), 1)
        _, kwargs = stage_app.calls[0]
        self.assertIs(kwargs["parent_fut"], parent)
        self.assertIs(kwargs["outputs"][0], file_obj)

    def test_stage_out_preserves_application_future_dependency(self):
        provider, dm, file_obj = self.provider_and_file()
        app_future = Future()
        stage_app = FakeStageApp(SimpleNamespace(name="stage-out-future"))
        provider._globus_stage_out_app = lambda executor, dfk: stage_app

        result = provider.stage_out(dm, "exec", file_obj, app_future)

        self.assertIs(result, stage_app.result)
        self.assertEqual(len(stage_app.calls), 1)
        args, kwargs = stage_app.calls[0]
        self.assertIs(args[0], app_future)
        self.assertIs(kwargs["inputs"][0], file_obj)


if __name__ == "__main__":
    unittest.main()
