"""Runtime probes for the monitoring STATUS primary key and insert handling."""

import datetime
import tempfile
import unittest
from unittest.mock import patch

import sqlalchemy as sa

from parsl.monitoring.db_manager import Database, DatabaseManager, STATUS, WORKFLOW


class MonitoringDatabaseRuntimeTest(unittest.TestCase):
    def make_database(self):
        path = tempfile.mktemp(suffix=".db")
        database = Database("sqlite:///" + path)
        now = datetime.datetime.now()
        database.insert(
            table=WORKFLOW,
            messages=[
                {
                    "run_id": "run-1",
                    "time_began": now,
                    "host": "host",
                    "user": "user",
                    "rundir": "/tmp/run",
                    "tasks_failed_count": 0,
                    "tasks_completed_count": 0,
                }
            ],
        )
        return database, now

    def status_message(self, timestamp):
        return {
            "task_id": 7,
            "run_id": "run-1",
            "task_status_name": "pending",
            "timestamp": timestamp,
            "try_id": 0,
        }

    def test_duplicate_status_key_is_rejected_by_database(self):
        database, timestamp = self.make_database()
        message = self.status_message(timestamp)
        database.insert(table=STATUS, messages=[message])

        with self.assertRaises(Exception):
            database.insert(table=STATUS, messages=[message])
        database.rollback()

        rows = database.session.execute(database.meta.tables[STATUS].select()).fetchall()
        self.assertEqual(len(rows), 1)

    def test_database_manager_insert_swallows_duplicate_error(self):
        database, timestamp = self.make_database()
        message = self.status_message(timestamp)
        database.insert(table=STATUS, messages=[message])

        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = database

        # Current _insert catches IntegrityError in its generic exception path.
        manager._insert(table=STATUS, messages=[message])

        rows = database.session.execute(database.meta.tables[STATUS].select()).fetchall()
        self.assertEqual(len(rows), 1)

    def test_database_manager_retries_transient_operational_error(self):
        class RetryingDatabase:
            def __init__(self):
                self.calls = 0

            def insert(self, *, table, messages):
                self.calls += 1
                if self.calls == 1:
                    raise sa.exc.OperationalError("database locked", None, None)

            def rollback(self):
                return None

        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = RetryingDatabase()

        with patch("parsl.monitoring.db_manager.time.sleep", return_value=None):
            manager._insert(table=STATUS, messages=[{"task_id": 1}])

        self.assertEqual(manager.db.calls, 2)


if __name__ == "__main__":
    unittest.main()
