"""Runtime probes for PBS Pro JSON status handling."""

import json
import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.pbspro.pbspro import PBSProProvider


class PbsproStatusRuntimeTest(unittest.TestCase):
    def provider_with_json(self, jobs):
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

    def test_known_job_updates_status(self):
        provider = self.provider_with_json({"42": {"job_state": "R"}})

        provider._status()

        self.assertEqual(provider.resources["42.server"]["status"].state, JobState.RUNNING)

    def test_foreign_job_currently_raises_key_error(self):
        provider = self.provider_with_json({"999": {"job_state": "R"}})

        with self.assertRaises(KeyError):
            provider._status()

    def test_scheduler_failure_preserves_status(self):
        provider = self.provider_with_json({})
        provider.execute_wait = lambda command: (1, "", "qstat failed")

        provider._status()

        self.assertEqual(provider.resources["42.server"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
