"""Runtime probe for WORKFLOW bookkeeping before insert success."""

import queue
import threading
import unittest
import datetime

from parsl.monitoring.db_manager import DatabaseManager, MessageType, WORKFLOW


class FailingWorkflowDatabase:
    def __init__(self):
        self.workflow_inserts = 0
        self.workflow_updates = 0

    def insert(self, *, table, messages):
        if table == WORKFLOW:
            self.workflow_inserts += 1
            raise ValueError("workflow insert failed")

    def update(self, *, table, columns, messages):
        if table == WORKFLOW:
            self.workflow_updates += 1

    def rollback(self):
        return None


class MonitoringWorkflowInsertBookkeepingRuntimeTest(unittest.TestCase):
    def test_failed_workflow_insert_is_used_by_close_currently(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = FailingWorkflowDatabase()
        manager.pending_priority_queue = queue.Queue()
        manager.pending_node_queue = queue.Queue()
        manager.pending_block_queue = queue.Queue()
        manager.pending_resource_queue = queue.Queue()
        manager.pending_worker_task_queue = queue.Queue()
        manager.external_exit_event = threading.Event()
        manager.workflow_end = False
        manager.workflow_start_message = None

        start_message = {
            "python_version": "3.11",
            "run_id": "run-1",
            "time_began": datetime.datetime.now(),
        }
        calls = {"priority": 0}

        def one_priority_batch(msg_queue):
            if msg_queue is manager.pending_priority_queue:
                calls["priority"] += 1
                if calls["priority"] == 1:
                    return [(MessageType.WORKFLOW_INFO, start_message)]
                if calls["priority"] == 2:
                    manager._kill_event.set()
            return []

        manager._get_messages_in_batch = one_priority_batch
        loop = threading.Thread(target=manager.start, args=(queue.Queue(),))
        loop.start()
        loop.join(timeout=2)
        self.assertFalse(loop.is_alive())

        manager.close()
        self.assertEqual(manager.db.workflow_inserts, 1)
        self.assertGreaterEqual(manager.db.workflow_updates, 1)


if __name__ == "__main__":
    unittest.main()
