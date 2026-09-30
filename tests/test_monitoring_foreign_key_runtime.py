"""Runtime probe for SQLite foreign-key enforcement in monitoring Database."""

import datetime
import tempfile
import unittest

from parsl.monitoring.db_manager import Database, STATUS


class MonitoringForeignKeyRuntimeTest(unittest.TestCase):
    def test_orphan_status_row_is_accepted_by_current_sqlite_engine(self):
        path = tempfile.mktemp(suffix=".db")
        database = Database("sqlite:///" + path)
        message = {
            "task_id": 11,
            "task_status_name": "running",
            "timestamp": datetime.datetime.now(),
            "run_id": "missing-workflow",
            "try_id": 0,
        }

        database.insert(table=STATUS, messages=[message])
        rows = database.session.execute(database.meta.tables[STATUS].select()).fetchall()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].run_id, "missing-workflow")


if __name__ == "__main__":
    unittest.main()
