"""Runtime probe for a live LocalProvider job without an exit-code file."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.local.local import LocalProvider


class LocalExitFileMissingRuntimeTest(unittest.TestCase):
    def test_missing_exit_code_file_currently_escapes_status_poll(self):
        provider = LocalProvider.__new__(LocalProvider)
        provider.resources = {
            "job-1": {
                "status": JobStatus(JobState.RUNNING),
                "script_path": "/tmp/job-1.sh",
                "remote_pid": 1,
            }
        }
        provider._is_alive = lambda _job: True

        def missing_file(_script_path, _suffix):
            raise FileNotFoundError("exit code file not created yet")

        provider._read_job_file = missing_file

        with self.assertRaises(FileNotFoundError):
            provider.status(["job-1"])


if __name__ == "__main__":
    unittest.main()
