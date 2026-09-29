"""Runtime probe for ClusterProvider.status request projection semantics."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.cluster_provider import ClusterProvider


class ProbeClusterProvider(ClusterProvider):
    def __init__(self):
        self._label = "probe"
        self.resources = {
            "J1": {"status": JobStatus(JobState.PENDING)},
            "J2": {"status": JobStatus(JobState.PENDING)},
        }
        self.polls = 0

    def _status(self):
        self.polls += 1
        for resource in self.resources.values():
            resource["status"] = JobStatus(JobState.RUNNING)

    def submit(self, *args, **kwargs):
        return "job"

    def cancel(self, job_ids):
        return [True for _ in job_ids]

    @property
    def status_polling_interval(self):
        return 1


class ClusterStatusRequestRuntimeTest(unittest.TestCase):
    def test_status_polls_once_and_preserves_duplicate_request_positions(self):
        provider = ProbeClusterProvider()
        result = provider.status(["J1", "J1", "J2"])

        self.assertEqual(provider.polls, 1)
        self.assertEqual(len(result), 3)
        self.assertEqual(result[0].state, JobState.RUNNING)
        self.assertEqual(result[1].state, JobState.RUNNING)
        self.assertEqual(result[2].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
