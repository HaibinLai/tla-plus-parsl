"""Runtime probes for Grid Engine qdel cancellation."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.grid_engine.grid_engine import GridEngineProvider


class GridEngineCancelRuntimeTest(unittest.TestCase):
    def provider_with_result(self, result):
        provider = GridEngineProvider.__new__(GridEngineProvider)
        provider.resources = {
            "42": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.execute_wait = lambda command: result
        return provider

    def test_successful_qdel_marks_known_job_completed(self):
        provider = self.provider_with_result((0, "", ""))

        self.assertEqual(provider.cancel(["42"]), [True])
        self.assertEqual(provider.resources["42"]["status"].state, JobState.COMPLETED)

    def test_failed_qdel_preserves_running_status(self):
        provider = self.provider_with_result((1, "", "qdel failed"))

        self.assertEqual(provider.cancel(["42"]), [False])
        self.assertEqual(provider.resources["42"]["status"].state, JobState.RUNNING)

    def test_successful_qdel_for_unknown_job_raises_key_error(self):
        provider = self.provider_with_result((0, "", ""))

        with self.assertRaises(KeyError):
            provider.cancel(["missing"])


if __name__ == "__main__":
    unittest.main()
