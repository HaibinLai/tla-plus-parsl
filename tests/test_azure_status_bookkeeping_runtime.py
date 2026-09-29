"""Runtime probe for Azure status bookkeeping."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.azure.azure import AzureProvider


class FakeVm:
    instance_view = type("InstanceView", (), {
        "statuses": [
            type("Status", (), {"display_status": "ProvisioningState"})(),
            type("Status", (), {"display_status": "VM running"})(),
        ],
    })()


class FakeVms:
    def get(self, group_name, job_id, expand=None):
        return FakeVm()


class FakeComputeClient:
    virtual_machines = FakeVms()


class AzureStatusBookkeepingRuntimeTest(unittest.TestCase):
    def test_running_status_does_not_update_local_resource_currently(self):
        provider = AzureProvider.__new__(AzureProvider)
        provider.group_name = "parsl.group"
        provider.compute_client = FakeComputeClient()
        provider.resources = {"vm-1": {"status": JobStatus(JobState.PENDING)}}

        statuses = provider.status(["vm-1"])

        self.assertEqual(statuses[0].state, JobState.RUNNING)
        self.assertEqual(provider.resources["vm-1"]["status"].state, JobState.PENDING)


if __name__ == "__main__":
    unittest.main()
