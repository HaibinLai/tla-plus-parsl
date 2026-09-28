"""Runtime probe for DatabaseManager's unbounded OperationalError retry."""

import threading
import unittest
from unittest.mock import patch

import sqlalchemy as sa

from parsl.monitoring.db_manager import DatabaseManager


class AlwaysLockedDatabase:
    def __init__(self):
        self.calls = 0
        self.stop = threading.Event()

    def insert(self, *, table, messages):
        self.calls += 1
        if self.stop.is_set():
            raise KeyboardInterrupt()
        raise sa.exc.OperationalError("database locked", None, None)

    def rollback(self):
        return None


class MonitoringPersistentRetryRuntimeTest(unittest.TestCase):
    def test_persistent_operational_error_does_not_return(self):
        database = AlwaysLockedDatabase()
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = database
        finished = threading.Event()
        errors = []

        def run_insert():
            try:
                manager._insert(table="status", messages=[{"task_id": 1}])
            except BaseException as exc:  # KeyboardInterrupt is the controlled stop
                errors.append(exc)
            finally:
                finished.set()

        def controlled_sleep(_seconds):
            database.stop.wait(timeout=0.01)

        with patch("parsl.monitoring.db_manager.time.sleep", side_effect=controlled_sleep):
            thread = threading.Thread(target=run_insert)
            thread.start()
            self.assertFalse(finished.wait(timeout=0.08))
            self.assertGreaterEqual(database.calls, 2)
            database.stop.set()
            thread.join(timeout=1)

        self.assertTrue(finished.is_set())
        self.assertEqual(type(errors[0]).__name__, "KeyboardInterrupt")


if __name__ == "__main__":
    unittest.main()
