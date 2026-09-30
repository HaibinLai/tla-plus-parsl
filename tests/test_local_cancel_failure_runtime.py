"""Runtime probe for LocalProvider cancellation-command failure reporting."""

import unittest
from unittest.mock import patch

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.local.local import LocalProvider


class LocalCancelFailureRuntimeTest(unittest.TestCase):
    def test_failed_kill_is_reported_successfully_currently(self):
        provider = LocalProvider()
        provider.resources = {
            "job-1": {
                "job_id": "job-1",
                "remote_pid": 123,
                "status": JobStatus(JobState.RUNNING),
            }
        }

        with patch(
            "parsl.providers.local.local.execute_wait",
            return_value=(1, "", "kill failed"),
        ):
            self.assertEqual(provider.cancel(["job-1"]), [True])

        self.assertEqual(provider.resources["job-1"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
