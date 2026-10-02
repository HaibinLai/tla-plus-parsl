import queue
import unittest

from parsl.monitoring.db_manager import DatabaseManager


class MonitoringQueueFairnessRuntimeTest(unittest.TestCase):
    def test_batch_threshold_admits_lower_queue_between_visits(self):
        manager = object.__new__(DatabaseManager)
        manager.batching_interval = 10.0
        manager.batching_threshold = 2

        priority = queue.Queue()
        lower = queue.Queue()
        for value in ("p1", "p2", "p3"):
            priority.put(value)
        lower.put("resource-1")

        first_batch = manager._get_messages_in_batch(priority)
        lower_batch = manager._get_messages_in_batch(lower)

        self.assertEqual(first_batch, ["p1", "p2"])
        self.assertEqual(lower_batch, ["resource-1"])
        self.assertEqual(priority.qsize(), 1)


if __name__ == "__main__":
    unittest.main()
