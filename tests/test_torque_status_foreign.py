"""Runtime regression probes for the Torque foreign-job TLA+ counterexample."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.torque.torque import TorqueProvider


class TorqueStatusParserTest(unittest.TestCase):
    def provider_with_output(self, output):
        provider = TorqueProvider()
        provider.resources = {
            "42.server": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.execute_wait = lambda command: (0, output, "")
        return provider

    def test_foreign_job_reproduces_tla_counterexample(self):
        # qstat's fifth column is the scheduler state. The job id is not ours.
        provider = self.provider_with_output("999.server x x x R\n")

        # TorqueProvider indexes self.resources[job_id] without a membership guard.
        with self.assertRaises(KeyError):
            provider._status()

    def test_known_job_updates_the_tracked_resource(self):
        provider = self.provider_with_output("42.server x x x C\n")

        provider._status()

        self.assertEqual(provider.resources["42.server"]["status"].state,
                         JobState.COMPLETED)


if __name__ == "__main__":
    unittest.main()
