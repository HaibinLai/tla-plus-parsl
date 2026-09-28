"""Runtime probes for Azure VM status translation."""

import unittest

from parsl.jobs.states import JobState
from parsl.providers.azure.azure import AzureProvider


class FakeVm:
    def __init__(self, display_statuses):
        self.instance_view = type("InstanceView", (), {
            "statuses": [type("Status", (), {"display_status": value})()
                         for value in display_statuses]
        })()


class FakeVms:
    def __init__(self, vm):
        self.vm = vm

    def get(self, group_name, job_id, expand=None):
        if isinstance(self.vm, BaseException):
            raise self.vm
        return self.vm


class FakeComputeClient:
    def __init__(self, vm):
        self.virtual_machines = FakeVms(vm)


class AzureStatusRuntimeTest(unittest.TestCase):
    def provider_with(self, statuses):
        provider = AzureProvider.__new__(AzureProvider)
        provider.group_name = "parsl.group"
        vm = statuses if isinstance(statuses, BaseException) else FakeVm(statuses)
        provider.compute_client = FakeComputeClient(vm)
        return provider

    def test_running_vm_is_translated(self):
        statuses = self.provider_with(["ProvisioningState", "VM running"]).status(["vm-1"])
        self.assertEqual([status.state for status in statuses], [JobState.RUNNING])

    def test_short_instance_view_is_pending(self):
        statuses = self.provider_with(["ProvisioningState"]).status(["vm-1"])
        self.assertEqual([status.state for status in statuses], [JobState.PENDING])

    def test_unknown_display_status_is_explicit_unknown(self):
        statuses = self.provider_with(["ProvisioningState", "VM expanding"]).status(["vm-1"])
        self.assertEqual([status.state for status in statuses], [JobState.UNKNOWN])

    def test_cloud_api_error_is_not_converted_to_a_status(self):
        provider = self.provider_with(RuntimeError("Azure unavailable"))

        with self.assertRaises(RuntimeError):
            provider.status(["vm-1"])


if __name__ == "__main__":
    unittest.main()
