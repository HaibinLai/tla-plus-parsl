"""Runtime probe for ClusterProvider.status unknown-job handling."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.cluster_provider import ClusterProvider


class ProbeClusterProvider(ClusterProvider):
    def submit(self, *args, **kwargs):
        return "known"

    def cancel(self, job_ids):
        return [True for _ in job_ids]

    @property
    def status_polling_interval(self):
        return 1

    def _status(self):
        # Simulate a successful scheduler poll.  The common method still
        # performs its local resources lookup after this returns.
        self.resources["known"]["status"] = JobStatus(JobState.RUNNING)


class ClusterProviderUnknownJobRuntimeTest(unittest.TestCase):
    def test_unknown_job_id_raises_after_successful_poll(self):
        provider = ProbeClusterProvider.__new__(ProbeClusterProvider)
        provider.resources = {
            "known": {"status": JobStatus(JobState.PENDING)},
        }

        with self.assertRaises(KeyError):
            provider.status(["unknown"])

        self.assertEqual(provider.resources["known"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
