"""Runtime probes for Globus Compute SDK Future propagation."""

import copy
import unittest
from concurrent.futures import Future

from parsl.executors.globus_compute import GlobusComputeExecutor


class FakeSDKExecutor:
    def __init__(self, future):
        self.resource_specification = {"default": True}
        self.user_endpoint_config = {"endpoint": "default"}
        self.future = future

    def submit(self, func, *args, **kwargs):
        return self.future


class GlobusComputeResultRuntimeTest(unittest.TestCase):
    def wrapper_with(self, future):
        sdk = FakeSDKExecutor(future)
        wrapper = GlobusComputeExecutor.__new__(GlobusComputeExecutor)
        wrapper.executor = sdk
        wrapper.resource_specification = copy.deepcopy(sdk.resource_specification)
        wrapper.user_endpoint_config = copy.deepcopy(sdk.user_endpoint_config)
        return wrapper

    def test_submit_returns_sdk_future_identity(self):
        sdk_future = Future()
        returned = self.wrapper_with(sdk_future).submit(lambda: 1, {})
        self.assertIs(returned, sdk_future)

    def test_sdk_success_exception_and_cancel_are_visible_directly(self):
        successful = Future()
        successful.set_result("done")
        self.assertEqual(self.wrapper_with(successful).submit(lambda: 1, {}).result(), "done")

        failed = Future()
        failed.set_exception(RuntimeError("remote failure"))
        with self.assertRaisesRegex(RuntimeError, "remote failure"):
            self.wrapper_with(failed).submit(lambda: 1, {}).result()

        cancelled = Future()
        self.assertTrue(cancelled.cancel())
        returned = self.wrapper_with(cancelled).submit(lambda: 1, {})
        self.assertTrue(returned.cancelled())


if __name__ == "__main__":
    unittest.main()
