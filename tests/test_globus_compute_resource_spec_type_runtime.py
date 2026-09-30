"""Runtime probe for Globus Compute resource-specification shape validation."""

import copy
import unittest
from concurrent.futures import Future

from parsl.executors.globus_compute import GlobusComputeExecutor


class FakeGlobusExecutor:
    resource_specification = {"default": "yes"}
    user_endpoint_config = {"endpoint": "default"}

    def submit(self, func, *args, **kwargs):
        return Future()


class GlobusComputeResourceSpecTypeRuntimeTest(unittest.TestCase):
    def test_non_mapping_resource_spec_exposes_attribute_error_currently(self):
        sdk = FakeGlobusExecutor()
        wrapper = GlobusComputeExecutor.__new__(GlobusComputeExecutor)
        wrapper.executor = sdk
        wrapper.resource_specification = copy.deepcopy(sdk.resource_specification)
        wrapper.user_endpoint_config = copy.deepcopy(sdk.user_endpoint_config)

        with self.assertRaises(AttributeError):
            wrapper.submit(lambda: 1, "not-a-mapping")

        self.assertEqual(sdk.resource_specification, {"default": "yes"})
        self.assertEqual(sdk.user_endpoint_config, {"endpoint": "default"})


if __name__ == "__main__":
    unittest.main()
