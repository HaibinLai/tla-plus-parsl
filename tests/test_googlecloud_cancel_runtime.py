"""Runtime probes for Google Cloud cancellation bookkeeping."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.googlecloud.googlecloud import GoogleCloudProvider


class FakeDeleteRequest:
    def __init__(self, error=None):
        self.error = error

    def execute(self):
        if self.error is not None:
            raise self.error
        return {"status": "DONE"}


class FakeInstances:
    def __init__(self, request):
        self.request = request
        self.calls = []

    def delete(self, **kwargs):
        self.calls.append(kwargs)
        return self.request


class FakeClient:
    def __init__(self, request):
        self._instances = FakeInstances(request)

    def instances(self):
        return self._instances


class GoogleCloudCancelRuntimeTest(unittest.TestCase):
    def provider_with(self, error=None):
        provider = GoogleCloudProvider.__new__(GoogleCloudProvider)
        provider.client = FakeClient(FakeDeleteRequest(error))
        provider.project_id = "project"
        provider.zone = "zone-a"
        provider.resources = {"vm-1": {"status": JobStatus(JobState.RUNNING)}}
        return provider

    def test_successful_delete_currently_leaves_running_local_resource(self):
        provider = self.provider_with()

        self.assertEqual(provider.cancel(["vm-1"]), [True])
        self.assertEqual(provider.resources["vm-1"]["status"].state, JobState.RUNNING)
        self.assertEqual(provider.client._instances.calls[0], {
            "project": "project", "zone": "zone-a", "instance": "vm-1"
        })

    def test_delete_failure_returns_false_and_preserves_status(self):
        provider = self.provider_with(RuntimeError("GCE unavailable"))

        self.assertEqual(provider.cancel(["vm-1"]), [False])
        self.assertEqual(provider.resources["vm-1"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
