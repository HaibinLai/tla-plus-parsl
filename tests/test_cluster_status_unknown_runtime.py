"""Runtime probe for stale IDs in the ClusterProvider status projection."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.cluster_provider import ClusterProvider


class ProbeClusterProvider(ClusterProvider):
    def __init__(self):
        # Keep the probe focused on ClusterProvider.status rather than scheduler
        # constructor validation and launcher setup.
        self.resources = {"known": {"status": JobStatus(JobState.RUNNING)}}

    def _status(self):
        return None

    def submit(self, *args, **kwargs):
        raise NotImplementedError

    def cancel(self, *args, **kwargs):
        raise NotImplementedError

    @property
    def status_polling_interval(self):
        return 1


class ClusterStatusUnknownRuntimeTest(unittest.TestCase):
    def test_stale_id_raises_from_base_projection_currently(self):
        provider = ProbeClusterProvider()

        with self.assertRaises(KeyError):
            provider.status(["known", "stale"])

    def test_known_id_still_returns_status(self):
        provider = ProbeClusterProvider()
        result = provider.status(["known"])

        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
