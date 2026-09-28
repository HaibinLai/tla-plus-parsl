"""Runtime probes for Torque qsub output parsing and resource registration."""

import tempfile
import unittest
from pathlib import Path

from parsl.jobs.states import JobState
from parsl.providers.torque.torque import TorqueProvider


class TorqueSubmitRuntimeTest(unittest.TestCase):
    def provider_with_result(self, result):
        provider = TorqueProvider()
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        provider.script_dir = directory.name
        provider.launcher = lambda command, tasks_per_node, nodes, script_dir: command
        provider._write_submit_script = lambda *args, **kwargs: None
        provider.execute_wait = lambda command: result
        return provider

    def test_job_id_output_registers_pending_resource(self):
        provider = self.provider_with_result((0, "123.server\n", ""))

        self.assertEqual(provider.submit("echo worker", tasks_per_node=1), "123.server")
        self.assertEqual(provider.resources["123.server"]["status"].state, JobState.PENDING)

    def test_empty_success_output_returns_none_without_resource(self):
        provider = self.provider_with_result((0, "\n", ""))

        self.assertIsNone(provider.submit("echo worker", tasks_per_node=1))
        self.assertEqual(provider.resources, {})

    def test_qsub_failure_returns_none_without_resource(self):
        provider = self.provider_with_result((1, "", "qsub failed"))

        self.assertIsNone(provider.submit("echo worker", tasks_per_node=1))
        self.assertEqual(provider.resources, {})

    def test_multiple_nonempty_lines_return_last_job_id(self):
        provider = self.provider_with_result((0, "first\nsecond\n", ""))

        self.assertEqual(provider.submit("echo worker", tasks_per_node=1), "second")
        self.assertIn("first", provider.resources)
        self.assertIn("second", provider.resources)


if __name__ == "__main__":
    unittest.main()
