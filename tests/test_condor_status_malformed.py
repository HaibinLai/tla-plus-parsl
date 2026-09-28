"""Runtime regression probes for the Condor status-parser TLA+ counterexample.

The scheduler command is replaced with a deterministic stub, so this test does
not require a Condor installation or a running scheduler.
"""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.condor.condor import CondorProvider


class CondorStatusParserTest(unittest.TestCase):
    def provider_with_output(self, output):
        provider = CondorProvider(cmd_chunk_size=100)
        provider.resources = {
            "42.0": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.execute_wait = lambda command: (0, output, "")
        return provider

    def test_truncated_line_reproduces_tla_counterexample(self):
        provider = self.provider_with_output("42.0\n")

        # Current CondorProvider._status reads parts[1] without a length check.
        with self.assertRaises(IndexError):
            provider._status()

    def test_valid_line_updates_the_known_resource(self):
        provider = self.provider_with_output("42.0 4\n")

        provider._status()

        self.assertEqual(provider.resources["42.0"]["status"].state,
                         JobState.COMPLETED)


if __name__ == "__main__":
    unittest.main()
