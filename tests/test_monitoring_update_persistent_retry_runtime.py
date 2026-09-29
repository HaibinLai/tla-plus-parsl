"""Runtime probe for DatabaseManager._update's unbounded retry path."""

import threading
import unittest
from unittest.mock import patch

import sqlalchemy as sa

from parsl.monitoring.db_manager import DatabaseManager


class AlwaysLockedUpdateDatabase:
    def __init__(self):
        self.calls = 0
        self.stop = threading.Event()

    def update(self, **kwargs):
        self.calls += 1
        if self.stop.is_set():
            raise KeyboardInterrupt()
        raise sa.exc.OperationalError("database locked", None, None)

    def rollback(self):
        return None


class MonitoringUpdatePersistentRetryRuntimeTest(unittest.TestCase):
    def test_persistent_update_operational_error_does_not_return(self):
        database = AlwaysLockedUpdateDatabase()
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = database
        finished = threading.Event()
        errors = []

        def run_update():
            try:
                manager._update(table="status", columns=["task_id"], messages=[{"task_id": 1}])
            except BaseException as exc:
                errors.append(exc)
            finally:
                finished.set()

        def controlled_sleep(_seconds):
            database.stop.wait(timeout=0.01)

        with patch("parsl.monitoring.db_manager.time.sleep", side_effect=controlled_sleep):
            thread = threading.Thread(target=run_update)
            thread.start()
            self.assertFalse(finished.wait(timeout=0.08))
            self.assertGreaterEqual(database.calls, 2)
            database.stop.set()
            thread.join(timeout=1)

        self.assertTrue(finished.is_set())
        self.assertEqual(type(errors[0]).__name__, "KeyboardInterrupt")


if __name__ == "__main__":
    unittest.main()
