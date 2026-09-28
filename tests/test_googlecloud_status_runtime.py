"""Runtime probes for Google Compute Engine status translation."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.googlecloud.googlecloud import GoogleCloudProvider


class FakeRequest:
    def __init__(self, response):
        self.response = response

    def execute(self):
        if isinstance(self.response, BaseException):
            raise self.response
        return self.response


class FakeInstances:
    def __init__(self, response):
        self.response = response

    def get(self, **kwargs):
        return FakeRequest(self.response)


class FakeClient:
    def __init__(self, response):
        self.response = response

    def instances(self):
        return FakeInstances(self.response)


class GoogleCloudStatusRuntimeTest(unittest.TestCase):
    def provider_with(self, response):
        provider = GoogleCloudProvider.__new__(GoogleCloudProvider)
        provider.client = FakeClient(response)
        provider.project_id = "project"
        provider.zone = "zone-a"
        provider.resources = {"vm-1": {"status": JobStatus(JobState.PENDING)}}
        return provider

    def test_running_status_is_translated_and_recorded(self):
        provider = self.provider_with({"status": "RUNNING"})

        statuses = provider.status(["vm-1"])

        self.assertEqual([status.state for status in statuses], [JobState.RUNNING])
        self.assertEqual(provider.resources["vm-1"]["status"].state, JobState.RUNNING)

    def test_unknown_compute_status_is_not_silently_coerced(self):
        provider = self.provider_with({"status": "NEW_PROVIDER_STATE"})

        with self.assertRaises(KeyError):
            provider.status(["vm-1"])

    def test_api_error_propagates_from_status(self):
        provider = self.provider_with(RuntimeError("GCE unavailable"))

        with self.assertRaises(RuntimeError):
            provider.status(["vm-1"])


if __name__ == "__main__":
    unittest.main()
