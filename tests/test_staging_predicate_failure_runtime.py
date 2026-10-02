import unittest

from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File


class FailingPredicateProvider:
    def can_stage_in(self, file_obj):
        raise RuntimeError("predicate failed")


class WorkingProvider:
    def __init__(self):
        self.calls = 0

    def can_stage_in(self, file_obj):
        self.calls += 1
        return True

    def stage_in(self, dm, executor, file_obj, parent_fut):
        return file_obj


class StagingPredicateFailureRuntimeTest(unittest.TestCase):
    def test_predicate_failure_prevents_later_provider_selection_currently(self):
        later = WorkingProvider()
        executor = type("Executor", (), {"storage_access": [FailingPredicateProvider(), later]})()
        dfk = type("DFK", (), {"executors": {"exec": executor}})()
        manager = DataManager(dfk)

        with self.assertRaisesRegex(RuntimeError, "predicate failed"):
            manager.stage_in(File("https://example.invalid/input"),
                             File("https://example.invalid/input"), "exec")

        self.assertEqual(later.calls, 0)


if __name__ == "__main__":
    unittest.main()
