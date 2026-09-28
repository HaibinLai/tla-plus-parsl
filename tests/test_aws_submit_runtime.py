"""Runtime probes for AWSProvider instance-launch submission."""

import unittest

from parsl.jobs.states import JobState
from parsl.providers.aws.aws import AWSProvider


class FakeInstance:
    def __init__(self, instance_id="i-123", state="pending"):
        self.instance_id = instance_id
        self.id = instance_id
        self.state = {"Name": state}


class AwsSubmitRuntimeTest(unittest.TestCase):
    def provider_with_spinup(self, response):
        provider = AWSProvider.__new__(AWSProvider)
        provider.resources = {}
        provider.nodes_per_block = 1
        provider.script_dir = None
        provider.launcher = lambda command, tasks_per_node, nodes, script_dir: command
        provider.generate_aws_id = lambda: "parsl.aws.test"
        provider.spin_up_instance = lambda command, job_name: response
        return provider

    def test_successful_instance_is_registered_pending(self):
        provider = self.provider_with_spinup([FakeInstance()])

        self.assertEqual(provider.submit("echo worker", tasks_per_node=1), "i-123")
        self.assertEqual(provider.resources["i-123"]["status"].state, JobState.PENDING)

    def test_failed_launch_returns_none_without_resource(self):
        provider = self.provider_with_spinup([None])

        self.assertIsNone(provider.submit("echo worker", tasks_per_node=1))
        self.assertEqual(provider.resources, {})

    def test_unknown_instance_state_defaults_to_pending(self):
        provider = self.provider_with_spinup([FakeInstance(state="unrecognized")])

        provider.submit("echo worker", tasks_per_node=1)

        self.assertEqual(provider.resources["i-123"]["status"].state, JobState.PENDING)

    def test_empty_launch_response_reproduces_unpacking_error(self):
        provider = self.provider_with_spinup([])

        with self.assertRaises(ValueError):
            provider.submit("echo worker", tasks_per_node=1)
        self.assertEqual(provider.resources, {})


if __name__ == "__main__":
    unittest.main()
