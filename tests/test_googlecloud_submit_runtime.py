"""Runtime probe for Google Cloud instance-name bookkeeping on API failure."""

import unittest

from parsl.providers.googlecloud.googlecloud import GoogleCloudProvider


class FailingRequest:
    def execute(self):
        raise RuntimeError("GCE image lookup failed")


class FailingImages:
    def getFromFamily(self, **kwargs):
        return FailingRequest()


class FailingClient:
    def images(self):
        return FailingImages()


class GoogleCloudSubmitRuntimeTest(unittest.TestCase):
    def test_failed_create_consumes_instance_number_currently(self):
        provider = GoogleCloudProvider.__new__(GoogleCloudProvider)
        provider.client = FailingClient()
        provider.project_id = "project"
        provider.zone = "zone-a"
        provider.os_project = "os-project"
        provider.os_family = "debian"
        provider.instance_type = "n1-standard-1"
        provider.num_instances = 0

        with self.assertRaises(RuntimeError):
            provider.create_instance("startup")

        # Current source increments before the API request, even though no
        # instance was created. This is the TLC current-model counterexample.
        self.assertEqual(provider.num_instances, 1)


if __name__ == "__main__":
    unittest.main()
