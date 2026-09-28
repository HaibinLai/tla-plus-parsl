"""Runtime probes for LocalProvider exit-file status inference."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.local.local import LocalProvider


class LocalProviderRuntimeTest(unittest.TestCase):
    def provider_for(self, script_path, exit_text, alive=True, cancelled=False):
        path = Path(script_path)
        path.with_name(path.name + ".ec").write_text(exit_text)
        provider = LocalProvider()
        job = {
            "job_id": "local-1",
            "status": JobStatus(JobState.RUNNING),
            "remote_pid": 123,
            "script_path": str(path),
        }
        if cancelled:
            job["cancelled"] = True
        provider.resources = {"local-1": job}
        return provider, alive

    def test_running_exit_marker_uses_process_liveness(self):
        with tempfile.TemporaryDirectory() as directory:
            provider, alive = self.provider_for(Path(directory) / "job", "-\n", alive=True)
            with patch.object(provider, "_is_alive", return_value=alive):
                provider.status(["local-1"])
            self.assertEqual(provider.resources["local-1"]["status"].state, JobState.RUNNING)

    def test_zero_exit_code_is_completed(self):
        with tempfile.TemporaryDirectory() as directory:
            provider, _ = self.provider_for(Path(directory) / "job", "0\n")
            with patch.object(provider, "_is_alive", return_value=False):
                provider.status(["local-1"])
            self.assertEqual(provider.resources["local-1"]["status"].state, JobState.COMPLETED)

    def test_malformed_exit_code_is_failed(self):
        with tempfile.TemporaryDirectory() as directory:
            provider, _ = self.provider_for(Path(directory) / "job", "not-an-int\n")
            with patch.object(provider, "_is_alive", return_value=False):
                provider.status(["local-1"])
            self.assertEqual(provider.resources["local-1"]["status"].state, JobState.FAILED)

    def test_dead_cancelled_process_is_cancelled(self):
        with tempfile.TemporaryDirectory() as directory:
            provider, _ = self.provider_for(Path(directory) / "job", "-\n", alive=False, cancelled=True)
            with patch.object(provider, "_is_alive", return_value=False):
                provider.status(["local-1"])
            self.assertEqual(provider.resources["local-1"]["status"].state, JobState.CANCELLED)


if __name__ == "__main__":
    unittest.main()
