"""Runtime probes for Slurm batched status polling."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.slurm.slurm import SlurmProvider, sacct_translate_table


class SlurmStatusBatchRuntimeTest(unittest.TestCase):
    def provider_with(self, result):
        provider = SlurmProvider.__new__(SlurmProvider)
        provider.resources = {
            "1": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "out-1",
                "job_stderr_path": "err-1",
            },
            "2": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "out-2",
                "job_stderr_path": "err-2",
            },
        }
        provider.status_batch_size = 50
        provider._cmd = "{}"
        provider._translate_table = sacct_translate_table
        provider.execute_wait = lambda command: result
        return provider

    def test_command_failure_preserves_all_previous_statuses(self):
        provider = self.provider_with((1, "", "scheduler unavailable"))

        provider._status()

        self.assertEqual(provider.resources["1"]["status"].state, JobState.RUNNING)
        self.assertEqual(provider.resources["2"]["status"].state, JobState.RUNNING)

    def test_successful_batch_updates_reported_and_missing_jobs(self):
        provider = self.provider_with((0, "1 RUNNING\n", ""))

        provider._status()

        self.assertEqual(provider.resources["1"]["status"].state, JobState.RUNNING)
        self.assertEqual(provider.resources["2"]["status"].state, JobState.COMPLETED)

    def test_foreign_scheduler_job_currently_raises_key_error(self):
        provider = self.provider_with((0, "999 RUNNING\n", ""))

        with self.assertRaises(KeyError):
            provider._status()


if __name__ == "__main__":
    unittest.main()
