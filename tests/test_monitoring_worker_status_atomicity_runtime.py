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

    def _insert(self, table, messages):
        self.calls.append(("insert", table, messages))
        if table == "status":
            # Current source swallows this failure inside _insert and continues.
            return None

    def _update(self, table, columns, messages):
        self.calls.append(("update", table, messages))


class MonitoringWorkerStatusAtomicityRuntimeTest(unittest.TestCase):
    def test_status_failure_still_updates_try_currently(self):
        manager = RecordingManager()
        # Make STATUS look like a failed write while preserving the source's
        # control flow: _insert returns, then _update(TRY) is executed.
        original_insert = manager._insert

        def failing_status_insert(table, messages):
            manager.calls.append(("insert-failed", table, messages))
            if table == "status":
                return None
            return original_insert(table, messages)

        manager._insert = failing_status_insert
        manager.start(mp.Queue())

        self.assertTrue(any(call[0] == "insert-failed" and call[1] == "status"
                            for call in manager.calls))
        self.assertTrue(any(call[0] == "update" and call[1] == "try" for call in manager.calls))


if __name__ == "__main__":
    unittest.main()
