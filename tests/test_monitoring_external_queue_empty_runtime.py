"""Runtime probe for stale multiprocessing.Queue.empty() at shutdown."""

import queue
import threading
import unittest

from parsl.monitoring.db_manager import DatabaseManager
from parsl.monitoring.message_type import MessageType


class StaleEmptyQueue:
    def __init__(self, item):
        self.item = item
        self.get_called = False

    def empty(self):
        # Simulate multiprocessing.Queue.empty() observing stale state.
        return True

    def get(self, timeout=None):
        self.get_called = True
        return self.item


class MonitoringExternalQueueEmptyRuntimeTest(unittest.TestCase):
    def test_stale_empty_observation_strands_message_currently(self):
        message = (MessageType.TASK_INFO, {"task_id": 7, "try_id": 0})
        external = StaleEmptyQueue(message)
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.pending_priority_queue = queue.Queue()
        kill_event = threading.Event()
        kill_event.set()

        manager._migrate_logs_to_internal(external, kill_event)

        self.assertFalse(external.get_called)
        self.assertTrue(manager.pending_priority_queue.empty())


if __name__ == "__main__":
    unittest.main()
