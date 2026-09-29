"""Runtime probe for permanent monitoring database update failures."""

import unittest

from parsl.monitoring.db_manager import DatabaseManager


class FailingDatabase:
    def __init__(self):
        self.update_calls = []
        self.rollback_calls = 0

    def update(self, **kwargs):
        self.update_calls.append(kwargs)
        raise ValueError("permanent schema error")

    def rollback(self):
        self.rollback_calls += 1


class MonitoringDBUpdatePermanentErrorRuntimeTest(unittest.TestCase):
    def test_update_swallows_permanent_error_after_batch_is_removed(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = FailingDatabase()
        message = {"run_id": "run", "task_id": 1}

        self.assertIsNone(manager._update(table="status", columns=["task_id"], messages=[message]))
        self.assertEqual(len(manager.db.update_calls), 1)
        self.assertEqual(manager.db.rollback_calls, 1)


if __name__ == "__main__":
    unittest.main()
