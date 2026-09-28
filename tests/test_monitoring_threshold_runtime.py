"""Runtime probe for zero monitoring batching threshold."""

import queue
import unittest

from parsl.monitoring.db_manager import DatabaseManager


class MonitoringThresholdRuntimeTest(unittest.TestCase):
    def test_zero_threshold_leaves_available_event_queued(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.batching_interval = 1
        manager.batching_threshold = 0
        messages = queue.Queue()
        messages.put("event")

        self.assertEqual(manager._get_messages_in_batch(messages), [])
        self.assertEqual(messages.qsize(), 1)


if __name__ == "__main__":
    unittest.main()
