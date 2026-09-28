"""Runtime probe for DatabaseManager external-queue shutdown draining."""

import queue
import tempfile
import threading
import time
import unittest

from parsl.monitoring.db_manager import DatabaseManager
from parsl.monitoring.message_type import MessageType


class MonitoringShutdownDrainRuntimeTest(unittest.TestCase):
    def test_migration_drains_messages_after_kill_event(self):
        manager = DatabaseManager(
            db_url="sqlite:///" + tempfile.mktemp(suffix=".db"),
            run_dir=tempfile.mkdtemp(),
            exit_event=threading.Event(),
        )
        external = queue.Queue()
        external.put((MessageType.TASK_INFO, {"task_id": 1, "try_id": 0}))
        kill_event = threading.Event()

        thread = threading.Thread(
            target=manager._migrate_logs_to_internal,
            args=(external, kill_event),
        )
        thread.start()
        # The migration loop checks both conditions, so setting kill after the
        # message is accepted still allows the queue to drain before exit.
        deadline = time.monotonic() + 2
        while manager.pending_priority_queue.empty() and time.monotonic() < deadline:
            time.sleep(0.01)
        kill_event.set()
        thread.join(timeout=2)

        self.assertFalse(thread.is_alive())
        self.assertTrue(external.empty())
        self.assertEqual(manager.pending_priority_queue.get_nowait(),
                         (MessageType.TASK_INFO, {"task_id": 1, "try_id": 0}))


if __name__ == "__main__":
    unittest.main()
