"""Probe inconsistent exception handling in JobStatus output properties."""

import unittest
from unittest.mock import patch

from parsl.jobs.states import JobState, JobStatus


class JobStatusOutputReadErrorRuntimeTest(unittest.TestCase):
    def test_stdout_swallows_permission_error(self):
        status = JobStatus(JobState.FAILED, stdout_path="unreadable")
        with patch("builtins.open", side_effect=PermissionError("denied")):
            self.assertIsNone(status.stdout)

    def test_stdout_summary_leaks_permission_error_currently(self):
        status = JobStatus(JobState.FAILED, stdout_path="unreadable")
        with patch("builtins.open", side_effect=PermissionError("denied")):
            with self.assertRaises(PermissionError):
                _ = status.stdout_summary


if __name__ == "__main__":
    unittest.main()
