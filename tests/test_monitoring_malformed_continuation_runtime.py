"""Runtime bridge for malformed monitoring batch continuation."""

import queue
import tempfile
import threading
import unittest

from parsl.monitoring.db_manager import DatabaseManager


class EmptyResourceQueue:
    def empty(self):
        return True

    def get(self, timeout=None):
        raise queue.Empty


class MonitoringMalformedContinuationRuntimeTest(unittest.TestCase):
    def test_malformed_record_aborts_remaining_batch_currently(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.pending_priority_queue = queue.Queue()
        manager.pending_node_queue = queue.Queue()
        manager.pending_block_queue = queue.Queue()
        manager.pending_resource_queue = queue.Queue()
        manager.pending_worker_task_queue = queue.Queue()
        manager.external_exit_event = threading.Event()
        manager.workflow_end = False
        manager.workflow_start_message = None
        manager.run_dir = tempfile.mkdtemp()
        manager.batching_interval = 0
        manager.batching_threshold = 100
        manager._inserted = []

        malformed = {
            "task_id": 1,
            "try_id": 0,
            "first_msg": False,
            "last_msg": False,
            "timestamp": 0,
        }
        valid = {
            "task_id": 2,
            "try_id": 0,
            "first_msg": False,
            "last_msg": True,
            "timestamp": 1,
        }

        def batches(msg_queue):
            if msg_queue is manager.pending_worker_task_queue:
                manager._kill_event.set()
                return [malformed, valid]
            return []

        manager._get_messages_in_batch = batches
        manager._insert = lambda table, messages: manager._inserted.append((table, messages))

        failures = []
        old_hook = threading.excepthook
        threading.excepthook = lambda args: failures.append(args.exc_type)
        try:
            thread = threading.Thread(target=manager.start, args=(EmptyResourceQueue(),))
            thread.start()
            thread.join(timeout=5)
        finally:
            threading.excepthook = old_hook

        self.assertFalse(thread.is_alive())
        self.assertEqual(failures, [RuntimeError])
        self.assertEqual(manager._inserted, [])


if __name__ == "__main__":
    unittest.main()
