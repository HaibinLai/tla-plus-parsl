"""Runtime probe for permanent monitoring database insert failures."""

import unittest

from parsl.monitoring.db_manager import DatabaseManager


class FailingDatabase:
    def __init__(self):
        self.insert_calls = []
        self.rollback_calls = 0

    def insert(self, **kwargs):
        self.insert_calls.append(kwargs)
        raise ValueError("permanent schema error")

    def rollback(self):
        self.rollback_calls += 1


class MonitoringDBPermanentErrorRuntimeTest(unittest.TestCase):
    def test_insert_swallows_permanent_error_after_batch_is_removed(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = FailingDatabase()
        message = {"run_id": "run", "task_id": 1}

        # Current _insert logs/rolls back and returns; it does not requeue or
        # raise, so the caller cannot preserve this already-drained message.
        self.assertIsNone(manager._insert(table="task", messages=[message]))
        self.assertEqual(len(manager.db.insert_calls), 1)
        self.assertEqual(manager.db.rollback_calls, 1)


if __name__ == "__main__":
    unittest.main()
