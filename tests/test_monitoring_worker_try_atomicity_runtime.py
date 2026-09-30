"""Runtime probe for partial STATUS/TRY persistence on worker first messages."""

import multiprocessing as mp
import queue
import unittest

from parsl.monitoring.db_manager import DatabaseManager, MessageType


class RecordingManager(DatabaseManager):
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
        self.db = RecordingDatabase(self)
        self.calls = []
        self._priority_done = False
        self._worker_done = False

    def _migrate_logs_to_internal(self, resource_queue, kill_event):
        return None

    def _get_messages_in_batch(self, msg_queue):
        if msg_queue is self.pending_priority_queue and not self._priority_done:
            self._priority_done = True
            return [(MessageType.TASK_INFO, {
                "task_id": 1, "try_id": 0, "run_id": "run",
            })]
        if msg_queue is self.pending_worker_task_queue and not self._worker_done:
            self._worker_done = True
            self.external_exit_event.set()
            return [{
                "task_id": 1, "try_id": 0, "first_msg": True,
                "last_msg": False, "timestamp": 1,
            }]
        return []

    def _update(self, table, columns, messages):
        self.calls.append(("update", table, messages))
        if table == "try":
            self.db.try_update_attempted = True
            raise ValueError("deterministic TRY write failure")


class RecordingDatabase:
    def __init__(self, manager):
        self.manager = manager
        self.status_present = False
        self.try_update_attempted = False

    def insert(self, *, table, messages):
        if table == "status":
            self.status_present = True

    def rollback(self):
        return None


class MonitoringWorkerTryAtomicityRuntimeTest(unittest.TestCase):
    def test_try_failure_leaves_status_without_try_currently(self):
        manager = RecordingManager()
        with self.assertRaises(RuntimeError):
            manager.start(mp.Queue())

        self.assertTrue(manager.db.status_present)
        self.assertTrue(manager.db.try_update_attempted)


if __name__ == "__main__":
    unittest.main()
