"""Runtime probes for Grid Engine qsub submission output parsing."""

import tempfile
import unittest
from pathlib import Path

from parsl.jobs.states import JobState
from parsl.providers.grid_engine.grid_engine import GridEngineProvider


class GridEngineSubmitRuntimeTest(unittest.TestCase):
    def provider_with_output(self, output, directory):
        provider = GridEngineProvider()
        provider.script_dir = directory
        provider.execute_wait = lambda command: (0, output, "")
        return provider

    def test_empty_success_output_returns_none_without_resource(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with_output("", directory)
            result = provider.submit("echo worker", tasks_per_node=1)
            self.assertIsNone(result)
            self.assertEqual(provider.resources, {})

    def test_job_id_output_registers_pending_resource(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with_output("12345\n", directory)
            result = provider.submit("echo worker", tasks_per_node=1)
            self.assertEqual(result, "12345")
            self.assertEqual(provider.resources["12345"]["status"].state, JobState.PENDING)
            self.assertTrue(any(Path(directory).iterdir()))


if __name__ == "__main__":
    unittest.main()
