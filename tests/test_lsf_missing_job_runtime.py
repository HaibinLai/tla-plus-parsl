"""Runtime probe for LSF missing-job status handling."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.lsf.lsf import LSFProvider


class LsfMissingJobRuntimeTest(unittest.TestCase):
    def test_missing_bjobs_entry_is_currently_reported_as_completed(self):
        provider = LSFProvider.__new__(LSFProvider)
        provider.resources = {"42": {"status": JobStatus(JobState.RUNNING)}}
        provider.execute_wait = lambda command: (0, "", "")

        provider._status()

        self.assertEqual(provider.resources["42"]["status"].state, JobState.COMPLETED)


if __name__ == "__main__":
    unittest.main()
