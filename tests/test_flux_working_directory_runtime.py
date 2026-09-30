"""Runtime probe for Flux task working-directory propagation."""

import sys
import types
import unittest
from unittest.mock import patch

from parsl.executors.flux import executor as flux_executor


class FakeJobspec:
    def __init__(self):
        self.cwd = None
        self.environment = None
        self.stdout = None
        self.stderr = None

    @classmethod
    def from_command(cls, **kwargs):
        return cls()


class FakeFluxJobModule:
    JobspecV1 = FakeJobspec


class FakeFluxFuture:
    def cancelled(self):
        return False

    def add_done_callback(self, callback):
        self.callback = callback


class FakeFluxExecutor:
    def __init__(self):
        self.jobspec = None

    def submit(self, jobspec):
        self.jobspec = jobspec
        return FakeFluxFuture()


class FluxWorkingDirectoryRuntimeTest(unittest.TestCase):
    def test_current_source_uses_submitter_cwd_instead_of_executor_working_dir(self):
        fake_flux = types.SimpleNamespace(job=FakeFluxJobModule)
        remote = FakeFluxExecutor()
        info = flux_executor._FluxJobInfo(
            future=flux_executor.FluxFutureWrapper(),
            task_id="0",
            infile="/executor-work/0_in.pkl",
            outfile="/executor-work/0_out.pkl",
            resource_spec={},
        )

        with patch.dict(sys.modules, {"flux": fake_flux, "flux.job": FakeFluxJobModule}):
            # _submit_single_job imports flux.job and uses the process cwd.
            with patch("os.getcwd", return_value="/submitter"):
                flux_executor._submit_single_job(remote, "/executor-work", info)

        self.assertIsNotNone(remote.jobspec)
        self.assertEqual(remote.jobspec.cwd, "/submitter")
        self.assertNotEqual(remote.jobspec.cwd, "/executor-work")


if __name__ == "__main__":
    unittest.main()
