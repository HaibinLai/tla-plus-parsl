"""Runtime probes for the LSF provider bkill cancellation boundary."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.lsf.lsf import LSFProvider


class LsfCancelRuntimeTest(unittest.TestCase):
    def provider_with_result(self, result):
        provider = LSFProvider.__new__(LSFProvider)
        provider.resources = {
            "42": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.execute_wait = lambda command: result
        return provider

    def test_successful_bkill_marks_known_job_cancelled(self):
        provider = self.provider_with_result((0, "", ""))

        self.assertEqual(provider.cancel(["42"]), [True])
        self.assertEqual(provider.resources["42"]["status"].state, JobState.CANCELLED)

    def test_failed_bkill_returns_false_and_preserves_status(self):
        provider = self.provider_with_result((1, "", "bkill failed"))

        self.assertEqual(provider.cancel(["42"]), [False])
        self.assertEqual(provider.resources["42"]["status"].state, JobState.RUNNING)

    def test_successful_bkill_for_unknown_job_raises_key_error(self):
        provider = self.provider_with_result((0, "", ""))

        with self.assertRaises(KeyError):
            provider.cancel(["missing"])


if __name__ == "__main__":
    unittest.main()
