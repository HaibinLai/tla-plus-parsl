"""Runtime probe for duplicate LSF bjobs lines."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.lsf.lsf import LSFProvider


class LSFDuplicateStatusRuntimeTest(unittest.TestCase):
    def test_duplicate_job_lines_raise_key_error_currently(self):
        provider = LSFProvider.__new__(LSFProvider)
        provider.resources = {
            "42": {"status": JobStatus(JobState.RUNNING)},
        }
        output = "42 RUN\n42 RUN\n"
        provider.execute_wait = lambda command: (0, output, "")

        with self.assertRaises(KeyError):
            provider._status()


if __name__ == "__main__":
    unittest.main()
