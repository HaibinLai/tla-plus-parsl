"""Runtime bridge for priority TASK/STATUS/TRY write consistency."""

import unittest

from parsl.monitoring.db_manager import DatabaseManager


class RecordingDatabase:
    def __init__(self):
        self.rows = {"task": 0, "status": 0, "try": 0}

    def insert(self, *, table, messages):
        if table == "status":
            raise ValueError("deterministic status write failure")
        self.rows[table] += len(messages)

    def rollback(self):
        return None


class MonitoringPriorityStatusAtomicityRuntimeTest(unittest.TestCase):
    def test_status_failure_leaves_task_and_try_metadata_currently(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = RecordingDatabase()
        message = {"task_id": 1, "try_id": 0, "run_id": "run"}

        manager._insert(table="task", messages=[message])
        manager._insert(table="status", messages=[message])
        manager._insert(table="try", messages=[message])

        self.assertEqual(manager.db.rows, {"task": 1, "status": 0, "try": 1})


if __name__ == "__main__":
    unittest.main()
