"""Runtime probe for AWS status result cardinality when EC2 omits an id."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.aws.aws import AWSProvider


class EmptyEc2Client:
    def describe_instances(self, **kwargs):
        return {"Reservations": []}


class AwsStatusMissingResultRuntimeTest(unittest.TestCase):
    def test_missing_requested_instance_returns_empty_list_currently(self):
        provider = AWSProvider.__new__(AWSProvider)
        provider.client = EmptyEc2Client()
        provider.resources = {"i-1": {"status": JobStatus(JobState.RUNNING)}}

        statuses = provider.status(["i-1"])

        self.assertEqual(statuses, [])
        self.assertEqual(provider.resources["i-1"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
