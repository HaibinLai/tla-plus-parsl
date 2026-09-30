"""Runtime probe for Google Cloud region-to-zone selection."""

import unittest

from parsl.providers.googlecloud.googlecloud import GoogleCloudProvider


class FakeRequest:
    def __init__(self, response):
        self.response = response

    def execute(self):
        return self.response


class FakeZones:
    def __init__(self, response):
        self.response = response

    def list(self, **kwargs):
        return FakeRequest(self.response)


class FakeClient:
    def __init__(self, response):
        self.response = response

    def zones(self):
        return FakeZones(self.response)


class GoogleCloudZoneSelectionRuntimeTest(unittest.TestCase):
    def test_missing_up_zone_returns_none_currently(self):
        provider = GoogleCloudProvider.__new__(GoogleCloudProvider)
        provider.client = FakeClient({
            "items": [{"name": "us-central1-a", "status": "DOWN"}],
        })
        provider.project_id = "project"

        # The constructor accepts this None and only fails later when an API
        # request is made with an invalid zone.
        self.assertIsNone(provider.get_zone("europe"))

    def test_zone_response_without_items_raises_key_error_currently(self):
        provider = GoogleCloudProvider.__new__(GoogleCloudProvider)
        provider.client = FakeClient({})
        provider.project_id = "project"

        with self.assertRaises(KeyError):
            provider.get_zone("europe")


if __name__ == "__main__":
    unittest.main()
