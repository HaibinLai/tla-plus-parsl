"""Runtime probe for AWS provider state-file publication after a partial write."""

import json
import tempfile
import unittest
from unittest.mock import patch

from parsl.providers.aws.aws import AWSProvider


class PartialStateFile:
    def __init__(self, path, real_open):
        self.path = path
        self.real_open = real_open

    def write(self, value):
        with self.real_open(self.path, "w") as target:
            target.write(value[: max(1, len(value) // 3)])
        raise OSError("interrupted state-file write")


class AwsStateFileAtomicityRuntimeTest(unittest.TestCase):
    def test_interrupted_write_leaves_corrupt_final_state_file_currently(self):
        path = tempfile.mktemp(suffix=".json")
        provider = AWSProvider.__new__(AWSProvider)
        provider.state_file = path
        provider.vpc_id = "vpc-1"
        provider.sg_id = "sg-1"
        provider.sn_ids = ["subnet-1"]
        provider.instances = ["i-1"]
        provider.instance_states = {}
        real_open = open

        def interrupted_open(target, mode="r", *args, **kwargs):
            if target == path and mode == "w":
                return PartialStateFile(path, real_open)
            return real_open(target, mode, *args, **kwargs)

        with patch("builtins.open", side_effect=interrupted_open):
            with self.assertRaises(OSError):
                provider.write_state_file()

        with open(path) as state_file:
            with self.assertRaises(json.JSONDecodeError):
                json.load(state_file)


if __name__ == "__main__":
    unittest.main()
