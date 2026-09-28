"""Runtime probes for Condor condor_submit output parsing."""

import tempfile
import unittest
from unittest.mock import patch

from parsl.jobs.states import JobState
from parsl.providers.condor.condor import CondorProvider
from parsl.providers.errors import ScaleOutFailed


class CondorSubmitRuntimeTest(unittest.TestCase):
    def provider_with_output(self, output, retcode=0):
        provider = CondorProvider()
        provider.execute_wait = lambda command: (retcode, output, "scheduler error")
        return provider

    def test_valid_cluster_line_registers_first_process_pending(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with_output("5 job(s) submitted to cluster 118907.\n")
            provider.script_dir = directory
            job_id = provider.submit("echo worker", tasks_per_node=1)

        self.assertEqual(job_id, "118907.0")
        self.assertEqual(provider.resources[job_id]["status"].state, JobState.PENDING)

    def test_empty_success_output_reproduces_index_error(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with_output("")
            provider.script_dir = directory
            with self.assertRaises(IndexError):
                provider.submit("echo worker", tasks_per_node=1)

        self.assertEqual(provider.resources, {})

    def test_malformed_numeric_line_reproduces_parse_index_error(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with_output("5\n")
            provider.script_dir = directory
            with self.assertRaises(IndexError):
                provider.submit("echo worker", tasks_per_node=1)

    def test_nonzero_submit_is_scale_out_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with_output("", retcode=1)
            provider.script_dir = directory
            with self.assertRaises(ScaleOutFailed):
                provider.submit("echo worker", tasks_per_node=1)


if __name__ == "__main__":
    unittest.main()
