"""Runtime probe for AWS instance-state refresh response shape."""

import unittest

from parsl.providers.aws.aws import AWSProvider


class EmptyReservationClient:
    def describe_instances(self, **kwargs):
        return {"Reservations": [{"Instances": []}]}


class AwsInstanceStateRuntimeTest(unittest.TestCase):
    def test_empty_reservation_exposes_index_error_currently(self):
        provider = AWSProvider.__new__(AWSProvider)
        provider.client = EmptyReservationClient()
        provider.instances = []
        provider.instance_states = {}

        with self.assertRaises(IndexError):
            provider.get_instance_state()


if __name__ == "__main__":
    unittest.main()
