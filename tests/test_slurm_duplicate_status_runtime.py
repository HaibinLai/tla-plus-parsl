"""Runtime probe for duplicate Slurm status records."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.slurm.slurm import SlurmProvider, sacct_translate_table


class SlurmDuplicateStatusRuntimeTest(unittest.TestCase):
    def test_duplicate_job_lines_raise_key_error_currently(self):
        provider = SlurmProvider.__new__(SlurmProvider)
        provider.resources = {
            "42": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "out-42",
                "job_stderr_path": "err-42",
            },
        }
        provider.status_batch_size = 50
        provider._cmd = "{}"
        provider._translate_table = sacct_translate_table
        provider.execute_wait = lambda command: (0, "42 RUNNING\n42 RUNNING\n", "")

        with self.assertRaises(KeyError):
            provider._status()


if __name__ == "__main__":
    unittest.main()
