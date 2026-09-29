"""Runtime probes for Globus endpoint working-directory validation."""

import unittest
from types import SimpleNamespace

from parsl.data_provider.globus import GlobusStaging


class GlobusEndpointPathRuntimeTest(unittest.TestCase):
    def test_child_local_path_is_rejected_by_current_implementation(self):
        provider = GlobusStaging(
            "endpoint",
            endpoint_path="/remote/work",
            local_path="/worker/data",
        )

        with self.assertRaises(Exception):
            provider._get_globus_endpoint(SimpleNamespace(working_dir="/worker"))

    def test_working_directory_itself_is_mapped(self):
        provider = GlobusStaging(
            "endpoint",
            endpoint_path="/remote/work",
            local_path="/worker",
        )

        endpoint = provider._get_globus_endpoint(SimpleNamespace(working_dir="/worker"))
        self.assertEqual(endpoint["endpoint_uuid"], "endpoint")
        self.assertEqual(endpoint["endpoint_path"], "/remote/work/.")
        self.assertEqual(endpoint["working_dir"], "/worker")

    def test_missing_working_directory_is_rejected(self):
        provider = GlobusStaging("endpoint")

        with self.assertRaises(ValueError):
            provider._get_globus_endpoint(SimpleNamespace(working_dir=None))


if __name__ == "__main__":
    unittest.main()
