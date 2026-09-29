"""Runtime probe for an EC2 status record absent from AWSProvider.resources."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.aws.aws import AWSProvider


class _FakeEc2Client:
    def describe_instances(self, **kwargs):
        return {
            "Reservations": [{
                "Instances": [{
                    "InstanceId": "i-unknown",
                    "State": {"Name": "running"},
                }],
            }],
        }


class AwsUnknownInstanceRuntimeTest(unittest.TestCase):
    def test_untracked_instance_aborts_status_poll(self):
        provider = AWSProvider.__new__(AWSProvider)
        provider.client = _FakeEc2Client()
        provider.resources = {
            "i-known": {"status": JobStatus(JobState.PENDING)},
        }

        with self.assertRaises(KeyError):
            provider.status(["i-unknown"])


if __name__ == "__main__":
    unittest.main()
