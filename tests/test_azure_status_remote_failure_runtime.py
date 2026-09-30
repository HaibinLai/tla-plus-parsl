"""Runtime probe for Azure status API failures aborting a batch."""

import unittest

from parsl.providers.azure.azure import AzureProvider


class FailingVms:
    def get(self, group_name, job_id, expand=None):
        if job_id == "deleted-vm":
            raise RuntimeError("VM not found")
        return type("Vm", (), {
            "instance_view": type("View", (), {
                "statuses": [type("S", (), {"display_status": "ProvisioningState"})(),
                             type("S", (), {"display_status": "VM running"})()]
            })()
        })()


class AzureStatusRemoteFailureRuntimeTest(unittest.TestCase):
    def test_remote_missing_vm_aborts_later_statuses_currently(self):
        provider = AzureProvider.__new__(AzureProvider)
        provider.group_name = "parsl.group"
        provider.compute_client = type("Client", (), {
            "virtual_machines": FailingVms()
        })()

        with self.assertRaises(RuntimeError):
            provider.status(["deleted-vm", "healthy-vm"])


if __name__ == "__main__":
    unittest.main()
