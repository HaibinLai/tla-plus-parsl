"""Runtime probe for Globus Compute shutdown cleanup ordering."""

import unittest

from parsl.executors.globus_compute import GlobusComputeExecutor


class FailingSdkExecutor:
    def __init__(self):
        self.watcher_requested = False

    def shutdown(self, **kwargs):
        raise RuntimeError("SDK shutdown failed")

    def _get_result_watcher(self):
        self.watcher_requested = True
        return RecordingWatcher()


class RecordingWatcher:
    def __init__(self):
        self.shutdown_called = False

    def shutdown(self, **kwargs):
        self.shutdown_called = True


class GlobusComputeShutdownCleanupRuntimeTest(unittest.TestCase):
    def test_sdk_shutdown_failure_skips_result_watcher_currently(self):
        sdk = FailingSdkExecutor()
        executor = GlobusComputeExecutor.__new__(GlobusComputeExecutor)
        executor.executor = sdk

        with self.assertRaises(RuntimeError):
            executor.shutdown()

        # The current source obtains the watcher only after SDK shutdown
        # returns, so the failure path leaves it untouched.
        self.assertFalse(sdk.watcher_requested)

    def test_candidate_cleanup_closes_watcher_after_sdk_failure(self):
        sdk = FailingSdkExecutor()
        watcher = RecordingWatcher()
        sdk._get_result_watcher = lambda: watcher

        try:
            sdk.shutdown(wait=False, cancel_futures=True)
        except RuntimeError:
            pass
        finally:
            watcher.shutdown(wait=False, cancel_futures=True)

        self.assertTrue(watcher.shutdown_called)


if __name__ == "__main__":
    unittest.main()
