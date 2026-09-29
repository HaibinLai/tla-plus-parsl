"""Runtime bridge for LocalProvider .ec marker precedence."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.local.local import LocalProvider


class LocalProviderExitStatusRuntimeTest(unittest.TestCase):
    def test_exit_marker_wins_over_liveness_and_cancel_request(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "job"
            script.with_name("job.ec").write_text("0\n")
            provider = LocalProvider()
            provider.resources = {
                "job-1": {
                    "job_id": "job-1",
                    "status": JobStatus(JobState.RUNNING),
                    "remote_pid": 123,
                    "script_path": str(script),
                    "cancelled": True,
                }
            }
            with patch.object(provider, "_is_alive", return_value=True):
                status = provider.status(["job-1"])[0]
            self.assertEqual(status.state, JobState.COMPLETED)
            self.assertEqual(status.exit_code, 0)

    def test_terminal_status_is_not_regressed_by_later_marker_change(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "job"
            marker = script.with_name("job.ec")
            marker.write_text("3\n")
            provider = LocalProvider()
            provider.resources = {
                "job-1": {
                    "job_id": "job-1",
                    "status": JobStatus(JobState.RUNNING),
                    "remote_pid": 123,
                    "script_path": str(script),
                }
            }
            with patch.object(provider, "_is_alive", return_value=False):
                self.assertEqual(provider.status(["job-1"])[0].state, JobState.FAILED)
            marker.write_text("0\n")
            self.assertEqual(provider.status(["job-1"])[0].state, JobState.FAILED)


if __name__ == "__main__":
    unittest.main()
