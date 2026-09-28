"""Runtime probes for LSF status translation and missing-job handling."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.lsf.lsf import LSFProvider


class LsfStatusRuntimeTest(unittest.TestCase):
    def provider_with_output(self, output):
        provider = LSFProvider()
        provider.resources = {
            "42": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.execute_wait = lambda command: (0, output, "")
        return provider

    def test_foreign_job_is_ignored(self):
        provider = self.provider_with_output("999 RUN\n")
        provider._status()
        self.assertEqual(provider.resources["42"]["status"].state, JobState.COMPLETED)

    def test_unknown_scheduler_state_is_exposed_as_unknown(self):
        provider = self.provider_with_output("42 MYSTERY\n")
        provider._status()
        self.assertEqual(provider.resources["42"]["status"].state, JobState.UNKNOWN)

    def test_known_scheduler_state_is_translated(self):
        provider = self.provider_with_output("42 RUN\n")
        provider._status()
        self.assertEqual(provider.resources["42"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
