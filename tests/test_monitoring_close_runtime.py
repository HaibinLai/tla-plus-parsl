"""Runtime probes for monitoring workflow finalization during close."""

import datetime
import threading
import unittest

from parsl.monitoring.db_manager import DatabaseManager, WORKFLOW


class MonitoringCloseRuntimeTest(unittest.TestCase):
    def manager_with(self, workflow_end, start_message):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.workflow_end = workflow_end
        manager.workflow_start_message = start_message
        manager.batching_interval = 1
        manager.batching_threshold = 10
        manager._kill_event = threading.Event()
        manager.updates = []
        manager._update = lambda **kwargs: manager.updates.append(kwargs)
        return manager

    def test_abnormal_close_updates_workflow_end_and_stops_manager(self):
        now = datetime.datetime.now()
        manager = self.manager_with(False, {"time_began": now})

        manager.close()

        self.assertEqual(len(manager.updates), 1)
        self.assertEqual(manager.updates[0]["table"], WORKFLOW)
        self.assertEqual(manager.updates[0]["columns"], [
            "run_id", "time_completed", "workflow_duration"
        ])
        self.assertTrue(manager._kill_event.is_set())
        self.assertEqual(manager.batching_interval, float("inf"))
        self.assertEqual(manager.batching_threshold, float("inf"))

    def test_normal_close_does_not_duplicate_workflow_finalization(self):
        manager = self.manager_with(True, {"time_began": datetime.datetime.now()})

        manager.close()

        self.assertEqual(manager.updates, [])
        self.assertTrue(manager._kill_event.is_set())


if __name__ == "__main__":
    unittest.main()
