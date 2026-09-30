"""Runtime probe for isolating malformed PBS Pro status records."""

import json
import unittest
from unittest.mock import patch

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.cluster_provider import ClusterProvider
from parsl.providers.pbspro.pbspro import PBSProProvider


class PbsproStatusBatchIsolationRuntimeTest(unittest.TestCase):
    def test_malformed_record_aborts_independent_valid_record_currently(self):
        provider = PBSProProvider.__new__(PBSProProvider)
        provider.resources = {
            "bad.server": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "bad.stdout",
                "job_stderr_path": "bad.stderr",
            },
            "good.server": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "good.stdout",
                "job_stderr_path": "good.stderr",
            },
        }
        output = json.dumps({"Jobs": {
            "bad.server": [],
            "good.server": {"job_state": "R"},
        }})

        with patch.object(ClusterProvider, "execute_wait", return_value=(0, output, "")):
            with self.assertRaises(AttributeError):
                provider._status()

        self.assertEqual(provider.resources["good.server"]["status"].state,
                         JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
