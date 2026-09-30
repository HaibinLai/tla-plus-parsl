"""Runtime probe for PBS Pro successful status responses missing active jobs."""

import json
import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.pbspro.pbspro import PBSProProvider


class PbsproMissingStatusRuntimeTest(unittest.TestCase):
    def provider_with_jobs(self, jobs):
        provider = PBSProProvider.__new__(PBSProProvider)
        provider.resources = {
            "42.server": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "42.out",
                "job_stderr_path": "42.err",
            },
        }
        provider.execute_wait = lambda command: (0, json.dumps({"Jobs": jobs}), "")
        return provider

    def test_empty_successful_qstat_marks_active_job_completed_currently(self):
        provider = self.provider_with_jobs({})

        provider._status()

        self.assertEqual(
            provider.resources["42.server"]["status"].state,
            JobState.COMPLETED,
        )

if __name__ == "__main__":
    unittest.main()
