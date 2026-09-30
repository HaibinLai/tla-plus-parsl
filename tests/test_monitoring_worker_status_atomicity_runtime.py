"""Runtime probe for partial STATUS/TRY persistence of worker first messages."""

import multiprocessing as mp
import queue
import unittest

from parsl.monitoring.db_manager import DatabaseManager, MessageType


class RecordingManager(DatabaseManager):
    def __init__(self):
        # Avoid constructing SQLAlchemy and the logging process machinery.
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
        self.db = FailingStatusDatabase()
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


class FailingStatusDatabase:
    def __init__(self):
        self.inserted_tables = []
        self.rollback_calls = 0

    def insert(self, *, table, messages):
        self.inserted_tables.append(table)
        if table == "status":
            raise ValueError("deterministic STATUS write failure")

    def rollback(self):
        self.rollback_calls += 1


class MonitoringWorkerStatusAtomicityRuntimeTest(unittest.TestCase):
    def test_status_failure_still_updates_try_currently(self):
        manager = RecordingManager()
        manager.start(mp.Queue())

        self.assertIn("status", manager.db.inserted_tables)
        self.assertGreaterEqual(manager.db.rollback_calls, 1)
        self.assertTrue(any(call[0] == "update" and call[1] == "try" for call in manager.calls))


if __name__ == "__main__":
    unittest.main()
