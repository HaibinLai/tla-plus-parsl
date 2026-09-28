"""Runtime probes for AWS EC2 instance-state translation."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.aws.aws import AWSProvider


class FakeEc2Client:
    def __init__(self, reservations):
        self.reservations = reservations

    def describe_instances(self, **kwargs):
        return {"Reservations": self.reservations}


def reservation(instance_id, state):
    return [{"Instances": [{"InstanceId": instance_id, "State": {"Name": state}}]}]


class AwsStatusRuntimeTest(unittest.TestCase):
    def provider_with(self, reservations):
        provider = AWSProvider.__new__(AWSProvider)
        provider.client = FakeEc2Client(reservations)
        provider.resources = {
            "i-1": {"status": JobStatus(JobState.RUNNING)},
        }
        return provider

    def test_missing_instance_response_leaves_previous_status(self):
        provider = self.provider_with([])

        self.assertEqual(provider.status(["i-1"]), [])
        self.assertEqual(provider.resources["i-1"]["status"].state, JobState.RUNNING)

    def test_ec2_state_is_translated_and_recorded(self):
        provider = self.provider_with(reservation("i-1", "running"))

        statuses = provider.status(["i-1"])

        self.assertEqual(len(statuses), 1)
        self.assertEqual(statuses[0].state, JobState.RUNNING)
        self.assertEqual(provider.resources["i-1"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
