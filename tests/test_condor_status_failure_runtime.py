"""Runtime probes for Condor status command-failure handling."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.condor.condor import CondorProvider


class CondorStatusFailureRuntimeTest(unittest.TestCase):
    @staticmethod
    def provider_with_output(output):
        provider = CondorProvider(cmd_chunk_size=100)
        provider.resources = {
            "42.0": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.execute_wait = lambda command: (1, output, "scheduler failed")
        return provider

    def test_failed_condor_q_can_overwrite_status_currently(self):
        provider = self.provider_with_output("42.0 4\n")

        provider._status()

        self.assertEqual(provider.resources["42.0"]["status"].state,
                         JobState.COMPLETED)

    def test_failed_condor_q_with_truncated_output_crashes_currently(self):
        provider = self.provider_with_output("42.0\n")

        with self.assertRaises(IndexError):
            provider._status()


if __name__ == "__main__":
    unittest.main()
