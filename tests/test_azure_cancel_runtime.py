"""Runtime probes for Azure VM cancellation lifecycle."""

import unittest

from parsl.providers.azure.azure import AzureProvider


class FakeDeleteOperation:
    def __init__(self, error=None):
        self.error = error

    def wait(self):
        if self.error is not None:
            raise self.error


class FakeVirtualMachines:
    def __init__(self, operation):
        self.operation = operation

    def delete(self, group_name, job_id):
        return self.operation


class FakeComputeClient:
    def __init__(self, operation):
        self.virtual_machines = FakeVirtualMachines(operation)


class AzureCancelRuntimeTest(unittest.TestCase):
    def provider_with(self, operation, linger=False):
        provider = AzureProvider.__new__(AzureProvider)
        provider.compute_client = FakeComputeClient(operation)
        provider.group_name = "group"
        provider.linger = linger
        provider.instances = ["vm-1"]
        return provider

    def test_linger_mode_rejects_cancel(self):
        provider = self.provider_with(FakeDeleteOperation(), linger=True)

        self.assertEqual(provider.cancel(["vm-1"]), [False])
        self.assertEqual(provider.instances, ["vm-1"])

    def test_delete_error_returns_false_and_preserves_instance(self):
        provider = self.provider_with(FakeDeleteOperation(RuntimeError("delete failed")))

        self.assertEqual(provider.cancel(["vm-1"]), [False])
        self.assertEqual(provider.instances, ["vm-1"])

    def test_successful_delete_returns_true_and_removes_instance(self):
        provider = self.provider_with(FakeDeleteOperation())

        self.assertEqual(provider.cancel(["vm-1"]), [True])
        self.assertEqual(provider.instances, [])

    def test_successful_delete_of_missing_local_id_returns_false_currently(self):
        # The VM API call succeeds, but list.remove raises ValueError because
        # local bookkeeping was already cleaned up.
        provider = self.provider_with(FakeDeleteOperation())
        provider.instances = []

        self.assertEqual(provider.cancel(["vm-1"]), [False])

    def test_duplicate_successful_delete_returns_partial_result_currently(self):
        # Both remote delete calls succeed, but the second local list.remove
        # raises because the first duplicate already removed the VM.
        provider = self.provider_with(FakeDeleteOperation())

        self.assertEqual(provider.cancel(["vm-1", "vm-1"]), [True, False])
        self.assertEqual(provider.instances, [])


if __name__ == "__main__":
    unittest.main()
