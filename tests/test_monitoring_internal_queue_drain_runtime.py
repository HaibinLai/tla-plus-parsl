"""Runtime probe for DatabaseManager's stale internal-queue empty check."""

import threading
import unittest
from unittest.mock import patch

from parsl.monitoring.db_manager import DatabaseManager


class StaleEmptyQueue:
    def __init__(self):
        self.message = {"kind": "resource"}

    def empty(self):
        # Deliberately model an observation racing with a producer/consumer.
        return True


class MonitoringInternalQueueDrainRuntimeTest(unittest.TestCase):
    def test_shutdown_exits_with_pending_internal_message_currently(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.external_exit_event = threading.Event()
        stale_queues = [StaleEmptyQueue() for _ in range(5)]
        (manager.pending_priority_queue,
         manager.pending_node_queue,
         manager.pending_block_queue,
         manager.pending_resource_queue,
         manager.pending_worker_task_queue) = stale_queues
        resource_queue = StaleEmptyQueue()

        class ThreadThatSignalsStop:
            def __init__(self, *, args, **_kwargs):
                self.args = args

            def start(self):
                # DatabaseManager.start creates the kill event before starting
                # this migration thread; signal it before the DB loop's first
                # stop-condition check.
                self.args[1].set()

        with patch("parsl.monitoring.db_manager.threading.Thread", ThreadThatSignalsStop):
            manager.start(resource_queue)

        # The real loop exits before any queue getter or DB insert is reached.
        self.assertIsNotNone(resource_queue.message)
        self.assertIsNotNone(manager.pending_resource_queue.message)


if __name__ == "__main__":
    unittest.main()
