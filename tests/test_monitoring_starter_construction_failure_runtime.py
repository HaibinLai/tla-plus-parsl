"""Runtime probe for monitoring starter construction failure handling."""

import multiprocessing
import unittest
from unittest.mock import patch

from parsl.monitoring import db_manager


class FailingDatabaseManager:
    def __init__(self, **kwargs):
        raise RuntimeError("database construction failed")


class MonitoringStarterConstructionFailureRuntimeTest(unittest.TestCase):
    def test_constructor_failure_is_masked_by_unbound_dbm_currently(self):
        with patch.object(db_manager, "DatabaseManager", FailingDatabaseManager):
            with self.assertRaises(UnboundLocalError):
                db_manager.dbm_starter(
                    multiprocessing.Queue(),
                    "sqlite:///:memory:",
                    "/tmp",
                    0,
                    multiprocessing.Event(),
                    None,
                )

    def test_candidate_guard_preserves_constructor_failure(self):
        with patch.object(db_manager, "DatabaseManager", FailingDatabaseManager):
            dbm = None
            with self.assertRaises(RuntimeError):
                try:
                    dbm = db_manager.DatabaseManager(db_url="sqlite:///:memory:")
                except Exception:
                    if dbm is not None:
                        dbm.close()
                    raise


if __name__ == "__main__":
    unittest.main()
