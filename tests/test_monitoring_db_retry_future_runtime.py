"""Runtime bridge for monitoring DB retry after a Future is terminal."""

import unittest
from concurrent.futures import Future
from unittest.mock import patch

import sqlalchemy as sa

from parsl.monitoring.db_manager import DatabaseManager


class _TransientInsertDB:
    def __init__(self):
        self.calls = 0
        self.rollbacks = 0

    def insert(self, *, table, messages):
        self.calls += 1
        if self.calls == 1:
            raise sa.exc.OperationalError("insert", {}, RuntimeError("locked"))

    def rollback(self):
        self.rollbacks += 1


class MonitoringDBRetryFutureRuntimeTest(unittest.TestCase):
    def test_insert_retry_does_not_change_terminal_future(self):
        app_future = Future()
        app_future.set_result("done")
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = _TransientInsertDB()

        with patch("parsl.monitoring.db_manager.time.sleep", return_value=None):
            manager._insert("task", [object()])

        self.assertTrue(app_future.done())
        self.assertEqual(app_future.result(), "done")
        self.assertEqual(manager.db.calls, 2)
        self.assertEqual(manager.db.rollbacks, 1)


if __name__ == "__main__":
    unittest.main()
