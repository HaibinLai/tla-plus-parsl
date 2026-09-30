"""Runtime probe for malformed PBS Pro JSON job records."""

import json
import unittest
from unittest.mock import patch

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.cluster_provider import ClusterProvider
from parsl.providers.pbspro.pbspro import PBSProProvider


class PbsproStatusShapeRuntimeTest(unittest.TestCase):
    def test_non_mapping_job_record_raises_attribute_error_currently(self):
        provider = PBSProProvider.__new__(PBSProProvider)
        provider.resources = {
            "42.server": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "stdout",
                "job_stderr_path": "stderr",
            }
        }
        output = json.dumps({"Jobs": {"42.server": []}})

        with patch.object(ClusterProvider, "execute_wait", return_value=(0, output, "")):
            with self.assertRaises(AttributeError):
                provider._status()


if __name__ == "__main__":
    unittest.main()
