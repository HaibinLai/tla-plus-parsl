"""Runtime probe for the shared Globus Compute submit configuration race."""

import copy
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.globus_compute import GlobusComputeExecutor


class RacySDKExecutor:
    def __init__(self):
        self.resource_specification = {"default": True}
        self.user_endpoint_config = {"endpoint": "default"}
        self.first_entered = threading.Event()
        self.release_first = threading.Event()
        self.observed = {}

    def submit(self, func, *args, **kwargs):
        name = func()
        if name == "A":
            self.first_entered.set()
            if not self.release_first.wait(timeout=2):
                raise AssertionError("timed out waiting for overlapping submit")
        self.observed[name] = copy.deepcopy(self.resource_specification)
        return Future()


class GlobusComputeSubmitRaceRuntimeTest(unittest.TestCase):
    def test_overlapping_submit_can_observe_the_wrong_resource_specification(self):
        sdk = RacySDKExecutor()
        wrapper = GlobusComputeExecutor.__new__(GlobusComputeExecutor)
        wrapper.executor = sdk
        wrapper.resource_specification = {"default": True}
        wrapper.user_endpoint_config = {"endpoint": "default"}
        errors = []

        def submit(name, resource):
            try:
                wrapper.submit(lambda: name, resource)
            except BaseException as exc:  # pragma: no cover - diagnostic only
                errors.append(exc)

        first = threading.Thread(target=submit, args=("A", {"task": "A"}))
        second = threading.Thread(target=submit, args=("B", {"task": "B"}))
        first.start()
        self.assertTrue(sdk.first_entered.wait(timeout=2))
        second.start()
        second.join(timeout=2)
        sdk.release_first.set()
        first.join(timeout=2)

        self.assertFalse(errors)
        self.assertEqual(sdk.observed["B"], {"task": "B"})
        self.assertNotEqual(sdk.observed["A"], {"task": "A"})
        self.assertEqual(sdk.resource_specification, {"default": True})


if __name__ == "__main__":
    unittest.main()
