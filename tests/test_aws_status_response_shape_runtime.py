"""Runtime probe for an AWS status response without Reservations."""

import unittest
from unittest.mock import Mock

from parsl.providers.aws.aws import AWSProvider


class AwsStatusResponseShapeRuntimeTest(unittest.TestCase):
    def test_missing_reservations_key_raises_key_error_currently(self):
        provider = AWSProvider.__new__(AWSProvider)
        provider.client = Mock()
        provider.client.describe_instances.return_value = {}
        provider.resources = {"i-1": {"status": None}}

        with self.assertRaises(KeyError):
            provider.status(["i-1"])


if __name__ == "__main__":
    unittest.main()
