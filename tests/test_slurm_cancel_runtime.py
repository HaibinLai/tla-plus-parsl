"""Runtime probes for Slurm cancellation bookkeeping."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.slurm.slurm import SlurmProvider


class SlurmCancelRuntimeTest(unittest.TestCase):
    def provider_with(self, result, resource_ids=("1",)):
        provider = SlurmProvider.__new__(SlurmProvider)
        provider.clusters = None
        provider.resources = {
            job_id: {"status": JobStatus(JobState.RUNNING)}
            for job_id in resource_ids
        }
        provider.execute_wait = lambda command: result
        return provider

    def test_successful_scancel_marks_resource_cancelled(self):
        provider = self.provider_with((0, "", ""))

        self.assertEqual(provider.cancel(["1"]), [True])
        self.assertEqual(provider.resources["1"]["status"].state, JobState.CANCELLED)

    def test_successful_scancel_with_foreign_id_raises_currently(self):
        provider = self.provider_with((0, "", ""), resource_ids=())

        with self.assertRaises(KeyError):
            provider.cancel(["foreign"])

    def test_batch_cancel_updates_known_prefix_before_stale_id_currently(self):
        provider = self.provider_with((0, "", ""), resource_ids=("known",))

        with self.assertRaises(KeyError):
            provider.cancel(["known", "stale"])

        self.assertEqual(provider.resources["known"]["status"].state,
                         JobState.CANCELLED)
