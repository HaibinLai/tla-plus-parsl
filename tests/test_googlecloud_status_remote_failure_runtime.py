"""Runtime probe for Google Cloud status failures aborting a batch."""

import unittest

from parsl.providers.googlecloud.googlecloud import GoogleCloudProvider


class FailingRequests:
    def get(self, **kwargs):
        if kwargs["instance"] == "deleted-vm":
            return type("Request", (), {
                "execute": lambda self: (_ for _ in ()).throw(RuntimeError("VM not found"))
            })()
        return type("Request", (), {
            "execute": lambda self: {"status": "RUNNING"}
        })()


class FailingClient:
    def instances(self):
        return FailingRequests()


class GoogleCloudStatusRemoteFailureRuntimeTest(unittest.TestCase):
    def test_remote_missing_vm_aborts_later_statuses_currently(self):
        provider = GoogleCloudProvider.__new__(GoogleCloudProvider)
        provider.client = FailingClient()
        provider.project_id = "project"
        provider.zone = "zone-a"
        provider.resources = {}

        with self.assertRaises(RuntimeError):
            provider.status(["deleted-vm", "healthy-vm"])


if __name__ == "__main__":
    unittest.main()
