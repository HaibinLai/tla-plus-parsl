"""Runtime probe for repeated DatabaseManager.close finalization."""

import datetime
import threading
import unittest

from parsl.monitoring.db_manager import DatabaseManager


class MonitoringCloseIdempotenceRuntimeTest(unittest.TestCase):
    def test_abnormal_close_repeats_workflow_update_currently(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.workflow_end = False
        manager.workflow_start_message = {"time_began": datetime.datetime.now()}
        manager.batching_interval = 1
        manager.batching_threshold = 1
        manager._kill_event = threading.Event()
        updates = []
        manager._update = lambda **kwargs: updates.append(kwargs)

        manager.close()
        manager.close()

        self.assertEqual(len(updates), 2)
        self.assertTrue(manager._kill_event.is_set())


if __name__ == "__main__":
    unittest.main()
