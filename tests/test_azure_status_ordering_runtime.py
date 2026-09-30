"""Runtime probe for Azure status-list ordering assumptions."""

import unittest

from parsl.providers.azure.azure import AzureProvider


class ReorderedVms:
    def get(self, group_name, job_id, expand=None):
        return type("Vm", (), {
            "instance_view": type("View", (), {
                "statuses": [
                    type("S", (), {"display_status": "VM running"})(),
                    type("S", (), {"display_status": "VM pending"})(),
                ]
            })()
        })()


class AzureStatusOrderingRuntimeTest(unittest.TestCase):
    def test_reordered_statuses_underreport_running_vm_currently(self):
        provider = AzureProvider.__new__(AzureProvider)
        provider.group_name = "parsl.group"
        provider.compute_client = type("Client", (), {"virtual_machines": ReorderedVms()})()

        statuses = provider.status(["vm-1"])

        self.assertEqual(statuses[0].state.name, "PENDING")


if __name__ == "__main__":
    unittest.main()
