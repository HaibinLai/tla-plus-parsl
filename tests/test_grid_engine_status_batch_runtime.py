"""Runtime probe for malformed Grid Engine records inside a status batch."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.grid_engine.grid_engine import GridEngineProvider


class GridEngineStatusBatchRuntimeTest(unittest.TestCase):
    def test_malformed_qstat_record_aborts_later_valid_record_currently(self):
        provider = GridEngineProvider.__new__(GridEngineProvider)
        provider.resources = {
            "42": {"status": JobStatus(JobState.PENDING)},
        }
        # The first record is truncated; the second is a valid RUNNING record.
        provider.execute_wait = lambda command: (0, "42\n42 a b c r\n", "")

        with self.assertRaises(IndexError):
            provider._status()

        self.assertEqual(provider.resources["42"]["status"].state, JobState.PENDING)


if __name__ == "__main__":
    unittest.main()
