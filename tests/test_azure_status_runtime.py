"""Runtime probes for Azure VM status translation."""

import unittest

from parsl.jobs.states import JobState
from parsl.providers.azure.azure import AzureProvider


class FakeVmClient:
    def __init__(self, vm):
        self.vm = vm

    def get(self, group, job_id, expand):
        if isinstance(self.vm, BaseException):
            raise self.vm
        return self.vm


class FakeComputeClient:
    def __init__(self, vm):
        self.virtual_machines = FakeVmClient(vm)


class AzureStatusRuntimeTest(unittest.TestCase):
    def provider_with(self, vm):
        provider = AzureProvider.__new__(AzureProvider)
        provider.compute_client = FakeComputeClient(vm)
        provider.group_name = "group"
        return provider

    def vm_with_status(self, display_status):
        status = type("Status", (), {"display_status": display_status})()
        instance_view = type("InstanceView", (), {"statuses": [None, status]})()
        return type("Vm", (), {"instance_view": instance_view})()

    def test_running_status_is_translated(self):
        provider = self.provider_with(self.vm_with_status("VM running"))

        statuses = provider.status(["vm-1"])

        self.assertEqual([status.state for status in statuses], [JobState.RUNNING])

    def test_missing_instance_view_status_is_pending(self):
        vm = type("Vm", (), {"instance_view": type("InstanceView", (), {"statuses": []})()})()
        provider = self.provider_with(vm)

        statuses = provider.status(["vm-1"])

        self.assertEqual([status.state for status in statuses], [JobState.PENDING])

    def test_cloud_api_error_is_not_converted_to_a_status(self):
        provider = self.provider_with(RuntimeError("Azure unavailable"))

        with self.assertRaises(RuntimeError):
            provider.status(["vm-1"])


if __name__ == "__main__":
    unittest.main()
