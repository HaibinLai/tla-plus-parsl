"""Runtime bridge for deferred worker-first monitoring and cross-table writes."""

import multiprocessing as mp
import queue
import unittest

from parsl.monitoring.db_manager import DatabaseManager, MessageType


class FailingDeferredDatabase:
    def __init__(self):
        self.status_attempted = False
        self.rollback_calls = 0

    def insert(self, *, table, messages):
        if table == "status":
            self.status_attempted = True
            raise ValueError("deterministic STATUS write failure")

    def rollback(self):
        self.rollback_calls += 1


class DeferredLifecycleManager(DatabaseManager):
    def __init__(self):
        self.workflow_end = False
        self.workflow_start_message = None
        self.batching_interval = 0
        self.batching_threshold = 999
        self.pending_priority_queue = queue.Queue()
        self.pending_node_queue = queue.Queue()
        self.pending_block_queue = queue.Queue()
        self.pending_resource_queue = queue.Queue()
        self.pending_worker_task_queue = queue.Queue()
        self.external_exit_event = mp.Event()
        self.db = FailingDeferredDatabase()
        self.calls = []
        self.priority_calls = 0
        self.worker_calls = 0

    def _migrate_logs_to_internal(self, resource_queue, kill_event):
        return None

    def _get_messages_in_batch(self, msg_queue):
        if msg_queue is self.pending_priority_queue:
            self.priority_calls += 1
            if self.priority_calls == 2:
                return [(MessageType.TASK_INFO, {
                    "task_id": 7, "try_id": 0, "run_id": "deferred-run",
                })]
            return []
        if msg_queue is self.pending_worker_task_queue:
            self.worker_calls += 1
            if self.worker_calls == 1:
                return [{
                    "task_id": 7, "try_id": 0, "first_msg": True,
                    "last_msg": False, "timestamp": 1,
                }]
            self.external_exit_event.set()
        return []

    def _update(self, table, columns, messages):
        self.calls.append((table, messages))


class MonitoringTaskTryWorkerLifecycleRuntimeTest(unittest.TestCase):
    def test_deferred_worker_status_failure_still_updates_try_currently(self):
        manager = DeferredLifecycleManager()
        manager.start(mp.Queue())

        self.assertTrue(manager.db.status_attempted)
        self.assertGreaterEqual(manager.db.rollback_calls, 1)
        self.assertTrue(any(table == "try" for table, _ in manager.calls))


if __name__ == "__main__":
    unittest.main()
