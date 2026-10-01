"""Runtime probe for Globus Compute cleanup masking an SDK submit failure."""

import unittest

from parsl.executors.globus_compute import GlobusComputeExecutor


class RestoreFailureSDK:
    def __init__(self):
        self._resource_specification = {"default": True}
        self.user_endpoint_config = {"endpoint": "default"}

    @property
    def resource_specification(self):
        return self._resource_specification

    @resource_specification.setter
    def resource_specification(self, value):
        if value == {"default": True}:
            raise ValueError("restore failed")
        self._resource_specification = value

    def submit(self, func, *args, **kwargs):
        raise RuntimeError("submit failed")


class GlobusComputeRestoreFailureRuntimeTest(unittest.TestCase):
    def test_restore_failure_masks_original_submit_error_currently(self):
        sdk = RestoreFailureSDK()
        wrapper = GlobusComputeExecutor.__new__(GlobusComputeExecutor)
        wrapper.executor = sdk
        wrapper.resource_specification = {"default": True}
        wrapper.user_endpoint_config = {"endpoint": "default"}

        with self.assertRaises(ValueError):
            wrapper.submit(lambda: None, {"task": "value"})


if __name__ == "__main__":
    unittest.main()
