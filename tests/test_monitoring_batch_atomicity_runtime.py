"""Runtime probe for mixed valid/duplicate monitoring STATUS batches."""

import datetime
import tempfile
import unittest

from parsl.monitoring.db_manager import Database, DatabaseManager, STATUS, WORKFLOW


class MonitoringBatchAtomicityRuntimeTest(unittest.TestCase):
    @staticmethod
    def make_database():
        database = Database("sqlite:///" + tempfile.mktemp(suffix=".db"))
        now = datetime.datetime.now()
        database.insert(
            table=WORKFLOW,
            messages=[{
                "run_id": "run-1",
                "time_began": now,
                "host": "host",
                "user": "user",
                "rundir": "/tmp/run",
                "tasks_failed_count": 0,
                "tasks_completed_count": 0,
            }],
        )
        return database, now

    @staticmethod
    def status_message(task_id, timestamp):
        return {
            "task_id": task_id,
            "run_id": "run-1",
            "task_status_name": "pending",
            "timestamp": timestamp,
            "try_id": 0,
        }

    def test_duplicate_in_batch_discards_valid_sibling_currently(self):
        database, timestamp = self.make_database()
        duplicate = self.status_message(7, timestamp)
        database.insert(table=STATUS, messages=[duplicate])

        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = database
        manager._insert(
            table=STATUS,
            messages=[self.status_message(8, timestamp), duplicate],
        )

        rows = database.session.execute(database.meta.tables[STATUS].select()).fetchall()
        self.assertEqual([row.task_id for row in rows], [7])


if __name__ == "__main__":
    unittest.main()
