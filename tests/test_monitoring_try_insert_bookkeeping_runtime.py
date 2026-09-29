"""Runtime probe for TRY-row bookkeeping before insert success."""

import queue
import threading
import unittest

from parsl.monitoring.db_manager import DatabaseManager, MessageType, TRY


class FailingTryDatabase:
    def __init__(self):
        self.try_inserts = 0
        self.try_updates = 0

    def insert(self, *, table, messages):
        if table == TRY:
            self.try_inserts += 1
            raise ValueError("try insert failed")

    def update(self, *, table, columns, messages):
        if table == TRY:
            self.try_updates += 1

    def rollback(self):
        return None


class MonitoringTryInsertBookkeepingRuntimeTest(unittest.TestCase):
    def test_failed_try_insert_is_classified_as_update_on_next_message_currently(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = FailingTryDatabase()
        manager.pending_priority_queue = queue.Queue()
        manager.pending_node_queue = queue.Queue()
        manager.pending_block_queue = queue.Queue()
        manager.pending_resource_queue = queue.Queue()
        manager.pending_worker_task_queue = queue.Queue()
        manager.external_exit_event = threading.Event()
        manager.workflow_end = False
        manager.workflow_start_message = None

        task = {"task_id": 7, "try_id": 0}
        calls = {"priority": 0}

        def one_priority_batch(msg_queue):
            if msg_queue is manager.pending_priority_queue:
                calls["priority"] += 1
                if calls["priority"] == 1:
                    return [(MessageType.TASK_INFO, task.copy())]
                if calls["priority"] == 2:
                    manager._kill_event.set()
                    return [(MessageType.TASK_INFO, task.copy())]
            return []

        manager._get_messages_in_batch = one_priority_batch
        loop = threading.Thread(target=manager.start, args=(queue.Queue(),))
        loop.start()
        loop.join(timeout=2)
        self.assertFalse(loop.is_alive())

        self.assertEqual(manager.db.try_inserts, 1)
        self.assertEqual(manager.db.try_updates, 1)


if __name__ == "__main__":
    unittest.main()
