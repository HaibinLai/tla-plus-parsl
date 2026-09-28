"""Runtime probes for the LSF provider bsub submission boundary."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.jobs.states import JobState
from parsl.providers.cluster_provider import ClusterProvider
from parsl.providers.lsf.lsf import LSFProvider


class LsfSubmitRuntimeTest(unittest.TestCase):
    def provider(self, result, redirection=False):
        provider = LSFProvider(bsub_redirection=redirection)
        tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(tempdir.cleanup)
        provider.script_dir = str(Path(tempdir.name))
        provider.launcher = lambda command, tasks_per_node, nodes, script_dir: command
        provider._write_submit_script = lambda *args, **kwargs: None
        seen = []

        def execute_wait(_provider, command, timeout=None):
            seen.append(command)
            return result

        self.addCleanup(patch.stopall)
        patch.object(ClusterProvider, "execute_wait", execute_wait).start()
        provider.seen_commands = seen
        return provider

    def test_valid_submission_registers_pending_job(self):
        provider = self.provider((0, "Job <123> is submitted to default queue <normal>.\n", ""))

        job_id = provider.submit("run-worker", tasks_per_node=2, job_name="test")

        self.assertEqual(job_id, "123")
        self.assertEqual(provider.resources["123"]["status"].state, JobState.PENDING)

    def test_scheduler_failure_returns_none_without_resource(self):
        provider = self.provider((1, "", "bsub failed"))

        self.assertIsNone(provider.submit("run-worker", tasks_per_node=1))
        self.assertEqual(provider.resources, {})

    def test_success_without_submission_marker_returns_none(self):
        provider = self.provider((0, "accepted\n", ""))

        self.assertIsNone(provider.submit("run-worker", tasks_per_node=1))
        self.assertEqual(provider.resources, {})

    def test_redirection_flag_changes_bsub_command(self):
        provider = self.provider((0, "Job <456> is submitted to default queue <normal>.\n", ""), True)

        self.assertEqual(provider.submit("run-worker", tasks_per_node=1), "456")
        self.assertIn("bsub <", provider.seen_commands[0])


if __name__ == "__main__":
    unittest.main()
