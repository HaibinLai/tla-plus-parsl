"""Runtime probes for AWS instance cancellation bookkeeping."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.aws.aws import AWSProvider


class FakeClient:
    def __init__(self, error=None):
        self.error = error
        self.calls = []

    def terminate_instances(self, **kwargs):
        self.calls.append(kwargs)
        if self.error is not None:
            raise self.error


class AWSCancelRuntimeTest(unittest.TestCase):
    def provider_with(self, instance_ids, error=None, linger=False):
        provider = AWSProvider.__new__(AWSProvider)
        provider.client = FakeClient(error)
        provider.linger = linger
        provider.instances = list(instance_ids)
        provider.resources = {
            instance_id: {"status": JobStatus(JobState.RUNNING)}
            for instance_id in instance_ids
        }
        return provider

    def test_successful_termination_marks_completed_and_removes_instance(self):
        provider = self.provider_with(["i-1"])

        self.assertEqual(provider.cancel(["i-1"]), [True])
        self.assertEqual(provider.resources["i-1"]["status"].state, JobState.COMPLETED)
        self.assertEqual(provider.instances, [])

    def test_successful_remote_termination_with_missing_local_id_raises_currently(self):
        provider = self.provider_with([])

        with self.assertRaises(KeyError):
            provider.cancel(["i-stale"])

        self.assertEqual(provider.client.calls, [{"InstanceIds": ["i-stale"]}])

    def test_duplicate_local_id_raises_after_remote_success_currently(self):
        provider = self.provider_with(["i-1"])

        with self.assertRaises(ValueError):
            provider.cancel(["i-1", "i-1"])

        # The remote request and first local removal already happened before
        # the second list.remove call exposed the exception.
        self.assertEqual(provider.client.calls, [{"InstanceIds": ["i-1", "i-1"]}])
        self.assertEqual(provider.instances, [])
        self.assertEqual(provider.resources["i-1"]["status"].state, JobState.COMPLETED)


if __name__ == "__main__":
    unittest.main()
