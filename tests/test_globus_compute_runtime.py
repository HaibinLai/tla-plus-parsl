"""Runtime probes for Globus Compute resource-configuration isolation."""

import copy
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.globus_compute import GlobusComputeExecutor


class FakeGlobusExecutor:
    def __init__(self, submit_fn=None, before_observe=None):
        self.resource_specification = {"default": "yes"}
        self.user_endpoint_config = {"endpoint": "default"}
        self.submit_fn = submit_fn
        self.before_observe = before_observe
        self.observed = []

    def submit(self, func, *args, **kwargs):
        if self.before_observe is not None:
            self.before_observe()
        self.observed.append((copy.deepcopy(self.resource_specification),
                              copy.deepcopy(self.user_endpoint_config)))
        if self.submit_fn is not None:
            return self.submit_fn()
        return Future()


class GlobusComputeRuntimeTest(unittest.TestCase):
    def wrapper_with(self, executor):
        wrapper = GlobusComputeExecutor.__new__(GlobusComputeExecutor)
        wrapper.executor = executor
        wrapper.resource_specification = copy.deepcopy(executor.resource_specification)
        wrapper.user_endpoint_config = copy.deepcopy(executor.user_endpoint_config)
        return wrapper

    def test_submit_applies_task_spec_and_restores_defaults(self):
        sdk = FakeGlobusExecutor()
        wrapper = self.wrapper_with(sdk)

        wrapper.submit(lambda: 1, {"ranks": 4, "user_endpoint_config": {"endpoint": "task"}})

        self.assertEqual(sdk.observed, [({"ranks": 4}, {"endpoint": "task"})])
        self.assertEqual(sdk.resource_specification, {"default": "yes"})
        self.assertEqual(sdk.user_endpoint_config, {"endpoint": "default"})

    def test_submit_restores_defaults_when_sdk_raises(self):
        sdk = FakeGlobusExecutor(submit_fn=lambda: (_ for _ in ()).throw(RuntimeError("submit failed")))
        wrapper = self.wrapper_with(sdk)

        with self.assertRaises(RuntimeError):
            wrapper.submit(lambda: 1, {"ranks": 2})

        self.assertEqual(sdk.resource_specification, {"default": "yes"})
        self.assertEqual(sdk.user_endpoint_config, {"endpoint": "default"})

    def test_concurrent_submits_can_observe_each_others_specification(self):
        first_entered = threading.Event()
        release_first = threading.Event()
        call_count = 0
        call_lock = threading.Lock()

        def before_observe():
            nonlocal call_count
            with call_lock:
                call_count += 1
                call_number = call_count
            if call_number == 1:
                first_entered.set()
                release_first.wait(timeout=5)
            else:
                release_first.set()

        sdk = FakeGlobusExecutor(before_observe=before_observe)
        wrapper = self.wrapper_with(sdk)
        errors = []

        def submit(spec):
            try:
                wrapper.submit(lambda: 1, spec)
            except Exception as exc:  # pragma: no cover - diagnostic path
                errors.append(exc)

        first = threading.Thread(target=submit, args=({"task": "A"},))
        second = threading.Thread(target=submit, args=({"task": "B"},))
        first.start()
        self.assertTrue(first_entered.wait(timeout=5))
        second.start()
        first.join(timeout=5)
        second.join(timeout=5)

        self.assertEqual(errors, [])
        self.assertEqual(len(sdk.observed), 2)
        self.assertIn({"task": "B"}, [spec for spec, _ in sdk.observed])
        self.assertNotIn({"task": "A"}, [spec for spec, _ in sdk.observed])


if __name__ == "__main__":
    unittest.main()
