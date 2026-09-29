"""Runtime probe for malformed monitoring worker-task messages."""

import tempfile
import threading
import unittest
import queue

from parsl.monitoring.db_manager import DatabaseManager


class EmptyResourceQueue:
    def empty(self):
        return True

    def get(self, timeout=None):
        raise queue.Empty


class MonitoringMalformedWorkerMessageRuntimeTest(unittest.TestCase):
    def test_message_with_neither_flag_crashes_database_thread_currently(self):
        manager = DatabaseManager(
            db_url="sqlite:///" + tempfile.mktemp(suffix=".db"),
            run_dir=tempfile.mkdtemp(),
            batching_interval=0,
            exit_event=threading.Event(),
        )
        malformed = {
            "task_id": 7,
            "try_id": 0,
            "first_msg": False,
            "last_msg": False,
            "timestamp": 0,
        }
        original = threading.excepthook
        failures = []
        threading.excepthook = lambda args: failures.append(args.exc_type)
        try:
            def staged_batch(msg_queue):
                if msg_queue is manager.pending_worker_task_queue:
                    manager._kill_event.set()
                    return [malformed]
                return []

            manager._get_messages_in_batch = staged_batch
            thread = threading.Thread(target=manager.start, args=(EmptyResourceQueue(),))
            thread.start()
            thread.join(timeout=5)
        finally:
            threading.excepthook = original

        self.assertFalse(thread.is_alive())
        self.assertEqual(failures, [RuntimeError])


if __name__ == "__main__":
    unittest.main()
