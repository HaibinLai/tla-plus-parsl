"""Runtime probe for truncated Slurm status records."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.slurm.slurm import SlurmProvider


class SlurmMalformedLineRuntimeTest(unittest.TestCase):
    def test_truncated_scheduler_line_currently_raises_value_error(self):
        provider = SlurmProvider.__new__(SlurmProvider)
        provider.resources = {
            "42": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "42.out",
                "job_stderr_path": "42.err",
            },
        }
        provider.status_batch_size = 10
        provider._cmd = "squeue {0}"
        provider._translate_table = {"R": JobState.RUNNING}
        provider.execute_wait = lambda command: (0, "42\n", "")

        with self.assertRaises(ValueError):
            provider._status()

        self.assertEqual(provider.resources["42"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
