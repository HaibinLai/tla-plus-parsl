"""Runtime probe for malformed PBS Pro qstat JSON."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.pbspro.pbspro import PBSProProvider


class PBSProMalformedJSONRuntimeTest(unittest.TestCase):
    def test_malformed_qstat_json_escapes_status_poll(self):
        provider = PBSProProvider.__new__(PBSProProvider)
        provider.resources = {
            "42.server": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "42.out",
                "job_stderr_path": "42.err",
            },
        }
        provider.execute_wait = lambda command: (0, "{not-json", "")

        with self.assertRaises(ValueError):
            provider._status()

        self.assertEqual(provider.resources["42.server"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
