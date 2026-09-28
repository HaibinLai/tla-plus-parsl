"""Runtime probes for PBS Pro qsub output parsing."""

import tempfile
import unittest
from pathlib import Path

from parsl.jobs.states import JobState
from parsl.providers.pbspro.pbspro import PBSProProvider


class PbsProSubmitRuntimeTest(unittest.TestCase):
    def provider_with_output(self, output, directory):
        provider = PBSProProvider()
        provider.script_dir = directory
        provider.execute_wait = lambda command: (0, output, "")
        return provider

    def test_successful_empty_qsub_output_returns_none_without_resource(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with_output("", directory)

            result = provider.submit(command="echo worker", tasks_per_node=1)

            self.assertIsNone(result)
            self.assertEqual(provider.resources, {})

    def test_job_id_output_registers_pending_resource(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with_output("123.server\n", directory)

            result = provider.submit(command="echo worker", tasks_per_node=1)

            self.assertEqual(result, "123.server")
            self.assertIn("123.server", provider.resources)
            self.assertEqual(provider.resources["123.server"]["status"].state, JobState.PENDING)
            self.assertTrue(any(Path(directory).iterdir()))


if __name__ == "__main__":
    unittest.main()
