"""Runtime probes for Grid Engine qstat status parsing."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.grid_engine.grid_engine import GridEngineProvider


class GridEngineStatusRuntimeTest(unittest.TestCase):
    def provider_with_output(self, output):
        provider = GridEngineProvider.__new__(GridEngineProvider)
        provider.resources = {
            "42": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.execute_wait = lambda command: (0, output, "")
        return provider

    def test_short_qstat_line_reproduces_index_error(self):
        provider = self.provider_with_output("42\n")

        with self.assertRaises(IndexError):
            provider._status()

    def test_valid_running_line_is_translated(self):
        provider = self.provider_with_output("42 a b c r\n")

        provider._status()

        self.assertEqual(provider.resources["42"]["status"].state, JobState.RUNNING)

    def test_foreign_job_is_ignored_and_known_job_is_completed_when_missing(self):
        provider = self.provider_with_output("999 a b c r\n")

        provider._status()

        self.assertEqual(provider.resources["42"]["status"].state, JobState.COMPLETED)


if __name__ == "__main__":
    unittest.main()
