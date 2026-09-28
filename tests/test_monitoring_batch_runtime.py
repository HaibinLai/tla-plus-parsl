"""Runtime probes for monitoring queue batch boundary behavior."""

import queue
import unittest

from parsl.monitoring.db_manager import DatabaseManager


class MonitoringBatchRuntimeTest(unittest.TestCase):
    def manager_with(self, interval, threshold=10):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.batching_interval = interval
        manager.batching_threshold = threshold
        return manager

    def test_zero_interval_returns_empty_before_reading_available_message_currently(self):
        manager = self.manager_with(0)
        messages = queue.Queue()
        messages.put("event")

        self.assertEqual(manager._get_messages_in_batch(messages), [])
        self.assertEqual(messages.qsize(), 1)

    def test_positive_interval_collects_available_message(self):
        manager = self.manager_with(1)
        messages = queue.Queue()
        messages.put("event")

        self.assertEqual(manager._get_messages_in_batch(messages), ["event"])


if __name__ == "__main__":
    unittest.main()
