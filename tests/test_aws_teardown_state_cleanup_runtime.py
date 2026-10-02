"""Runtime probe for AWS teardown with an already-removed state file."""

import tempfile
import unittest
from unittest.mock import Mock

from parsl.providers.aws.aws import AWSProvider


class AwsTeardownStateCleanupRuntimeTest(unittest.TestCase):
    def test_missing_state_file_leaks_file_not_found_currently(self):
        state_path = tempfile.mktemp(suffix=".json")
        provider = AWSProvider.__new__(AWSProvider)
        provider.instances = []
        provider.sn_ids = []
        provider.internet_gateway = None
        provider.route_table = None
        provider.sg_id = None
        provider.vpc_id = None
        provider.config = {"state_file_path": state_path}
        provider.client = Mock()
        provider.shut_down_instance = Mock()
        provider.show_summary = Mock()

        with self.assertRaises(FileNotFoundError):
            provider.teardown()

        provider.show_summary.assert_called_once()


if __name__ == "__main__":
    unittest.main()
