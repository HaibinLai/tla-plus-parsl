"""Runtime probe for Torque successful status responses missing active jobs."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.torque.torque import TorqueProvider


class TorqueMissingStatusRuntimeTest(unittest.TestCase):
    def test_empty_successful_qstat_marks_active_job_completed_currently(self):
        provider = TorqueProvider.__new__(TorqueProvider)
        provider.resources = {
            "42.server": {
                "status": JobStatus(JobState.RUNNING),
            },
        }
        provider.execute_wait = lambda command: (0, "", "")

        provider._status()

        self.assertEqual(
            provider.resources["42.server"]["status"].state,
            JobState.COMPLETED,
        )


if __name__ == "__main__":
    unittest.main()
