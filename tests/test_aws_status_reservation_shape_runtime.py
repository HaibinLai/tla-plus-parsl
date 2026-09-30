"""Runtime probe for malformed nested AWS reservation responses."""

import unittest

from parsl.providers.aws.aws import AWSProvider


class ReservationShapeClient:
    def describe_instances(self, **kwargs):
        return {
            "Reservations": [
                {},
                {"Instances": [{"InstanceId": "healthy-vm", "State": {"Name": "running"}}]},
            ]
        }


class AwsStatusReservationShapeRuntimeTest(unittest.TestCase):
    def test_missing_instances_field_aborts_later_reservations_currently(self):
        provider = AWSProvider.__new__(AWSProvider)
        provider.client = ReservationShapeClient()
        provider.resources = {"healthy-vm": {"status": None}}

        with self.assertRaises(KeyError):
            provider.status(["malformed-vm", "healthy-vm"])


if __name__ == "__main__":
    unittest.main()
