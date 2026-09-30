"""Runtime probe for Grid Engine successful status responses missing jobs."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.grid_engine.grid_engine import GridEngineProvider


class GridEngineMissingStatusRuntimeTest(unittest.TestCase):
    def test_empty_successful_qstat_marks_active_job_completed_currently(self):
        provider = GridEngineProvider.__new__(GridEngineProvider)
        provider.resources = {"42": {"status": JobStatus(JobState.RUNNING)}}
        provider.execute_wait = lambda command: (0, "", "")

        provider._status()

        self.assertEqual(provider.resources["42"]["status"].state, JobState.COMPLETED)


if __name__ == "__main__":
    unittest.main()
