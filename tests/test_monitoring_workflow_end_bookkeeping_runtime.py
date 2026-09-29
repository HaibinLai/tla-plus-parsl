"""Runtime probe for WORKFLOW end-update bookkeeping after failure."""

import queue
import threading
import unittest

from parsl.monitoring.db_manager import DatabaseManager, MessageType, WORKFLOW


class FailingWorkflowUpdateDatabase:
    def __init__(self):
        self.workflow_updates = 0

    def insert(self, *, table, messages):
        return None

    def update(self, *, table, columns, messages):
        if table == WORKFLOW:
            self.workflow_updates += 1
            raise ValueError("workflow end update failed")

    def rollback(self):
        return None


class MonitoringWorkflowEndBookkeepingRuntimeTest(unittest.TestCase):
    def test_failed_workflow_end_update_marks_end_and_skips_retry_currently(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.db = FailingWorkflowUpdateDatabase()
        manager.pending_priority_queue = queue.Queue()
        manager.pending_node_queue = queue.Queue()
        manager.pending_block_queue = queue.Queue()
        manager.pending_resource_queue = queue.Queue()
        manager.pending_worker_task_queue = queue.Queue()
        manager.external_exit_event = threading.Event()
        manager.workflow_end = False
        manager.workflow_start_message = None

        end_message = {"run_id": "run-1", "tasks_failed_count": 0,
                       "tasks_completed_count": 1, "time_completed": None}
        calls = {"priority": 0}

        def one_priority_batch(msg_queue):
            if msg_queue is manager.pending_priority_queue:
                calls["priority"] += 1
                if calls["priority"] == 1:
                    return [(MessageType.WORKFLOW_INFO, end_message)]
                if calls["priority"] == 2:
                    manager._kill_event.set()
            return []

        manager._get_messages_in_batch = one_priority_batch
        loop = threading.Thread(target=manager.start, args=(queue.Queue(),))
        loop.start()
        loop.join(timeout=2)
        self.assertFalse(loop.is_alive())

        self.assertTrue(manager.workflow_end)
        self.assertGreaterEqual(manager.db.workflow_updates, 1)
        attempts_before_close = manager.db.workflow_updates
        manager.close()
        self.assertEqual(manager.db.workflow_updates, attempts_before_close)


if __name__ == "__main__":
    unittest.main()
