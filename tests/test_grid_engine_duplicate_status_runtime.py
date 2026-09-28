"""Runtime probe for duplicate Grid Engine qstat lines."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.grid_engine.grid_engine import GridEngineProvider


class GridEngineDuplicateStatusRuntimeTest(unittest.TestCase):
    def test_duplicate_job_lines_raise_value_error_currently(self):
        provider = GridEngineProvider.__new__(GridEngineProvider)
        provider.resources = {
            "42": {"status": JobStatus(JobState.RUNNING)},
        }
        output = "42 a b c r\n42 a b c r\n"
        provider.execute_wait = lambda command: (0, output, "")

        with self.assertRaises(ValueError):
            provider._status()


if __name__ == "__main__":
    unittest.main()
