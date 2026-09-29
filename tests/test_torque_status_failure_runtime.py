"""Runtime probe for Torque status parsing after qstat failure."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.torque.torque import TorqueProvider


class TorqueStatusFailureRuntimeTest(unittest.TestCase):
    def test_failed_qstat_currently_applies_stale_stdout(self):
        provider = TorqueProvider()
        provider.resources = {
            "42.server": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.execute_wait = lambda command: (1, "42.server x x x C\n", "qstat failed")

        provider._status()

        self.assertEqual(provider.resources["42.server"]["status"].state, JobState.COMPLETED)


if __name__ == "__main__":
    unittest.main()
