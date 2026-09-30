"""Runtime probe for malformed LSF submit-response identifiers."""

import unittest
from unittest.mock import patch

from parsl.providers.cluster_provider import ClusterProvider
from parsl.providers.lsf.lsf import LSFProvider


class LsfSubmitJobIdRuntimeTest(unittest.TestCase):
    def test_malformed_success_line_publishes_non_job_token_currently(self):
        provider = LSFProvider.__new__(LSFProvider)
        provider.resources = {}
        provider.script_dir = "."
        provider.bsub_redirection = False
        provider.nodes_per_block = 1
        provider.scheduler_options = ""
        provider.worker_init = ""
        provider.walltime = "00:10:00"
        provider.launcher = lambda command, tasks_per_node, nodes_per_block, script_dir: command

        with patch.object(ClusterProvider, "_write_submit_script"), \
                patch.object(ClusterProvider, "execute_wait", return_value=(0, "Job is submitted to queue\n", "")):
            job_id = provider.submit("worker", 1)

        self.assertEqual(job_id, "is")
        self.assertIn("is", provider.resources)


if __name__ == "__main__":
    unittest.main()
