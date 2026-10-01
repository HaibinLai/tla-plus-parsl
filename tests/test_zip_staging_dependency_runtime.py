"""Runtime bridge for ZipFileStaging's application-Future dependency wiring."""

import tempfile
import unittest
from concurrent.futures import Future
from types import SimpleNamespace
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.zip import ZipFileStaging


class CapturingStageApp:
    def __init__(self):
        self.calls = []
        self.result = Future()

    def __call__(self, *args, **kwargs):
        self.calls.append((args, kwargs))
        return self.result


class ZipStagingDependencyRuntimeTest(unittest.TestCase):
    def test_stage_out_preserves_application_future_dependency(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = ZipFileStaging()
            dm = SimpleNamespace(dfk=SimpleNamespace(executors={
                "exec": SimpleNamespace(working_dir=directory),
            }))
            parent = Future()
            file_obj = File("zip:/tmp/archive.zip/result.bin")
            stage_app = CapturingStageApp()

            with patch("parsl.data_provider.zip._zip_stage_out_app", return_value=stage_app):
                result = provider.stage_out(dm, "exec", file_obj, parent)

            self.assertIs(result, stage_app.result)
            self.assertEqual(len(stage_app.calls), 1)
            _, kwargs = stage_app.calls[0]
            self.assertIs(kwargs["parent_fut"], parent)
            self.assertIs(kwargs["inputs"][0], file_obj)


if __name__ == "__main__":
    unittest.main()
