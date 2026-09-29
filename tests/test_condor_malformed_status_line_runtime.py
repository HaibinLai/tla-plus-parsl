"""Runtime probe for malformed successful Condor status output."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.condor.condor import CondorProvider


class CondorMalformedStatusLineRuntimeTest(unittest.TestCase):
    def test_successful_command_with_truncated_line_crashes_parser(self):
        provider = CondorProvider(cmd_chunk_size=100)
        provider.resources = {"42.0": {"status": JobStatus(JobState.RUNNING)}}
        provider.execute_wait = lambda command: (0, "42.0\n", "")

        with self.assertRaises(IndexError):
            provider._status()


if __name__ == "__main__":
    unittest.main()
