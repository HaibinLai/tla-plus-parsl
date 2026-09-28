"""Runtime probes for Azure VM provisioning and partial setup failures."""

import types
import unittest

from parsl.jobs.states import JobState
from parsl.providers.azure import azure as azure_module
from parsl.providers.azure.azure import AzureProvider

azure_module.DiskCreateOption = types.SimpleNamespace(attach="attach")


class FakeAsync:
    def __init__(self, value=None, error=None):
        self.value = value
        self.error = error

    def result(self):
        if self.error is not None:
            raise self.error
        return self.value

    def wait(self):
        if self.error is not None:
            raise self.error
        return self.value


class FakeGroups:
    def create_or_update(self, group, params):
        return None


class FakeResourceClient:
    def __init__(self):
        self.resource_groups = FakeGroups()


class FakeVirtualMachines:
    def __init__(self, disk_attach_error=None):
        self.disk_attach_error = disk_attach_error
        self.create_count = 0

    def create_or_update(self, group, name, params):
        self.create_count += 1
        if self.create_count == 1:
            vm = types.SimpleNamespace(
                id="/subscriptions/test/vm-1",
                name=name,
                storage_profile=types.SimpleNamespace(data_disks=[]),
            )
            return FakeAsync(vm)
        return FakeAsync(error=self.disk_attach_error)

    def start(self, group, name):
        return FakeAsync()

    def run_command(self, group, name, params):
        return FakeAsync()


class FakeComputeClient:
    def __init__(self, disk_attach_error=None):
        self.virtual_machines = FakeVirtualMachines(disk_attach_error)


class AzureSubmitRuntimeTest(unittest.TestCase):
    def provider_with(self, disk_attach_error=None):
        provider = AzureProvider.__new__(AzureProvider)
        provider.resource_client = FakeResourceClient()
        provider.compute_client = FakeComputeClient(disk_attach_error)
        provider.network_client = object()
        provider.resources = {}
        provider.instances = []
        provider.group_name = "group"
        provider.location = "region"
        provider.region = "region"
        provider.vnet_name = "vnet"
        provider.script_dir = None
        provider.worker_init = ""
        provider.linger = False
        provider.launcher = lambda command, tasks_per_node, nodes, script_dir: command
        provider.vm_reference = {
            "admin_username": "user",
            "password": "password",
            "vm_size": "small",
            "publisher": "publisher",
            "offer": "offer",
            "sku": "sku",
            "version": "latest",
            "disk_size_gb": 10,
        }
        provider.create_nic = lambda network_client: types.SimpleNamespace(id="nic-1")
        provider.create_disk = lambda: (types.SimpleNamespace(id="disk-1"), "disk-name")
        return provider

    def test_successful_setup_registers_pending_instance(self):
        provider = self.provider_with()

        result = provider.submit("echo worker", tasks_per_node=1)

        self.assertIn(result, provider.instances)
        self.assertEqual(provider.resources["/subscriptions/test/vm-1"]["status"].state,
                         JobState.PENDING)

    def test_disk_attach_failure_leaves_partial_state_currently(self):
        provider = self.provider_with(RuntimeError("disk attach failed"))

        with self.assertRaises(RuntimeError):
            provider.submit("echo worker", tasks_per_node=1)

        self.assertEqual(len(provider.instances), 1)
        self.assertIn("/subscriptions/test/vm-1", provider.resources)


if __name__ == "__main__":
    unittest.main()
