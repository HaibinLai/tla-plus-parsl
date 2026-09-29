"""Runtime probes for DataManager's ordered staging-provider dispatch."""

import unittest
from concurrent.futures import Future

from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File


class Executor:
    def __init__(self, providers):
        self.storage_access = providers


class DFK:
    def __init__(self, providers):
        self.executors = {"exec": Executor(providers)}


class Provider:
    def __init__(self, name, accepts, result):
        self.name = name
        self.accepts = accepts
        self.result = result
        self.calls = []

    def can_stage_in(self, file_obj):
        self.calls.append(("can", file_obj.url))
        return self.accepts

    def stage_in(self, dm, executor, file_obj, parent_fut):
        self.calls.append(("stage", file_obj.url))
        return self.result


class StagingProviderDispatchRuntimeTest(unittest.TestCase):
    def test_first_capable_provider_wins_and_future_is_returned(self):
        first = Provider("first", True, Future())
        second = Provider("second", True, None)
        manager = DataManager(DFK([first, second]))

        file_obj = File("https://example.invalid/input")
        result = manager.stage_in(file_obj, file_obj, "exec")

        self.assertIs(result, first.result)
        self.assertEqual([call[0] for call in first.calls], ["can", "stage"])
        self.assertEqual(second.calls, [])

    def test_none_result_is_terminal_and_returns_input_file(self):
        provider = Provider("noop", True, None)
        manager = DataManager(DFK([provider]))
        file_obj = File("https://example.invalid/input")

        self.assertIs(manager.stage_in(file_obj, file_obj, "exec"), file_obj)
        self.assertEqual([call[0] for call in provider.calls], ["can", "stage"])

    def test_no_capable_provider_is_an_explicit_error(self):
        provider = Provider("reject", False, None)
        manager = DataManager(DFK([provider]))
        file_obj = File("https://example.invalid/input")

        with self.assertRaises(ValueError):
            manager.stage_in(file_obj, file_obj, "exec")


if __name__ == "__main__":
    unittest.main()
