"""Runtime probe for LocalProvider.status query scoping."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.local.local import LocalProvider


class LocalProviderStatusScopeRuntimeTest(unittest.TestCase):
    def test_unrequested_missing_resource_breaks_requested_status_query(self):
        with tempfile.TemporaryDirectory() as directory:
            requested_path = Path(directory) / "requested"
            (Path(directory) / "requested.ec").write_text("0\n")
            provider = LocalProvider()
            provider.resources = {
                "requested": {
                    "job_id": "requested",
                    "status": JobStatus(JobState.RUNNING),
                    "remote_pid": 123,
                    "script_path": str(requested_path),
                },
                "stale": {
                    "job_id": "stale",
                    "status": JobStatus(JobState.RUNNING),
                    "remote_pid": 124,
                    "script_path": str(Path(directory) / "missing"),
                },
            }

            with patch.object(provider, "_is_alive", return_value=False):
                with self.assertRaises(FileNotFoundError):
                    provider.status(["requested"])

            self.assertEqual(
                provider.resources["requested"]["status"].state,
                JobState.COMPLETED,
            )


if __name__ == "__main__":
    unittest.main()
