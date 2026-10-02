"""Runtime probe for DataManager transfer-failure provider isolation."""

import unittest

from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File


class Executor:
    def __init__(self, providers):
        self.storage_access = providers


class DFK:
    def __init__(self, providers):
        self.executors = {"exec": Executor(providers)}


class Provider:
    def __init__(self, raises=False, result=None):
        self.raises = raises
        self.result = result
        self.calls = []

    def can_stage_in(self, file_obj):
        self.calls.append("can")
        return True

    def stage_in(self, dm, executor, file_obj, parent_fut):
        self.calls.append("stage")
        if self.raises:
            raise RuntimeError("first staging backend unavailable")
        return self.result


class StagingProviderTransferFailureRuntimeTest(unittest.TestCase):
    def test_first_transfer_failure_aborts_before_later_provider_currently(self):
        first = Provider(raises=True)
        second = Provider(result=None)
        manager = DataManager(DFK([first, second]))
        file_obj = File("https://example.invalid/input")

        with self.assertRaisesRegex(RuntimeError, "first staging backend"):
            manager.stage_in(file_obj, file_obj, "exec")

        self.assertEqual(first.calls, ["can", "stage"])
        self.assertEqual(second.calls, [])


if __name__ == "__main__":
    unittest.main()
