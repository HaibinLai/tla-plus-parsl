"""Runtime bridge for AWS unknown-instance polling and Future terminality."""

import unittest
from concurrent.futures import Future

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.aws.aws import AWSProvider


class _UnknownThenHealthyEc2:
    def describe_instances(self, **kwargs):
        return {
            "Reservations": [{
                "Instances": [
                    {"InstanceId": "i-unknown", "State": {"Name": "running"}},
                    {"InstanceId": "i-known", "State": {"Name": "running"}},
                ]
            }]
        }


class AwsUnknownFutureMonitoringRuntimeTest(unittest.TestCase):
    def test_unknown_instance_strands_healthy_future_and_monitoring_currently(self):
        provider = AWSProvider.__new__(AWSProvider)
        provider.client = _UnknownThenHealthyEc2()
        provider.resources = {
            "i-known": {"status": JobStatus(JobState.PENDING)},
        }
        healthy_future = Future()
        monitor_events = []

        with self.assertRaises(KeyError):
            statuses = provider.status(["i-unknown", "i-known"])
            if statuses:
                healthy_future.set_result(statuses[-1])
                monitor_events.append("succeeded")

        self.assertFalse(healthy_future.done())
        self.assertEqual(monitor_events, [])


if __name__ == "__main__":
    unittest.main()
