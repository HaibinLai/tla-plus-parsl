"""Runtime probes for Condor chunked cancellation and unknown-job handling."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.condor.condor import CondorProvider


class CondorCancelRuntimeTest(unittest.TestCase):
    def provider_with_result(self, result, chunk_size=2):
        provider = CondorProvider.__new__(CondorProvider)
        provider.cmd_chunk_size = chunk_size
        provider.resources = {
            "known": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.execute_wait = lambda command: result
        return provider

    def test_successful_cancel_ignores_unknown_job(self):
        provider = self.provider_with_result((0, "", ""))

        self.assertEqual(provider.cancel(["known", "missing"]), [True, True])
        self.assertEqual(provider.resources["known"]["status"].state, JobState.CANCELLED)

    def test_failed_chunk_returns_false_for_each_requested_job(self):
        provider = self.provider_with_result((1, "", "condor_rm failed"))

        self.assertEqual(provider.cancel(["known", "missing"]), [False, False])
        self.assertEqual(provider.resources["known"]["status"].state, JobState.RUNNING)

    def test_cancellation_is_submitted_in_chunks(self):
        provider = self.provider_with_result((0, "", ""), chunk_size=1)
        commands = []
        provider.execute_wait = lambda command: (commands.append(command) or (0, "", ""))

        self.assertEqual(provider.cancel(["known", "missing"]), [True, True])
        self.assertEqual(len(commands), 2)
        self.assertIn("known", commands[0])
        self.assertIn("missing", commands[1])


if __name__ == "__main__":
    unittest.main()
