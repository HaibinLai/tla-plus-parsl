"""Runtime probe for Azure cancellation resource-map cleanup."""

import unittest

from parsl.providers.azure.azure import AzureProvider


class FakeDeleteOperation:
    def wait(self):
        return None


class FakeVirtualMachines:
    def delete(self, group_name, job_id):
        return FakeDeleteOperation()


class FakeComputeClient:
    virtual_machines = FakeVirtualMachines()


class AzureCancelBookkeepingRuntimeTest(unittest.TestCase):
    def test_successful_delete_leaves_resources_entry_currently(self):
        provider = AzureProvider.__new__(AzureProvider)
        provider.compute_client = FakeComputeClient()
        provider.group_name = "group"
        provider.linger = False
        provider.instances = ["vm-1"]
        provider.resources = {"vm-1": {"job_id": "vm-1", "status": "PENDING"}}

        self.assertEqual(provider.cancel(["vm-1"]), [True])
        self.assertEqual(provider.instances, [])
        self.assertIn("vm-1", provider.resources)


if __name__ == "__main__":
    unittest.main()
