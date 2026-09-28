"""Runtime probe for worker last-message ordering in DatabaseManager."""

import datetime
import queue
import tempfile
import threading
import unittest

from parsl.monitoring.db_manager import DatabaseManager, STATUS, TASK, TRY
from parsl.monitoring.message_type import MessageType


class EmptyResourceQueue:
    def empty(self):
        return True

    def get(self, timeout=None):
        raise queue.Empty


class MonitoringLastMessageRuntimeTest(unittest.TestCase):
    def test_last_worker_message_can_be_persisted_before_try_row(self):
        now = datetime.datetime.now()
        task = {
            "task_id": 9,
            "try_id": 0,
            "run_id": "run-last-race",
            "task_func_name": "work",
            "task_memoize": "false",
            "task_fail_count": 0,
            "task_fail_cost": 0.0,
            "task_executor": "local",
            "timestamp": now,
        }
        last = {
            "task_id": 9,
            "try_id": 0,
            "run_id": "run-last-race",
            "first_msg": False,
            "last_msg": True,
            "timestamp": now + datetime.timedelta(seconds=1),
            "block_id": "local-0",
            "hostname": "worker-a",
        }
        manager = DatabaseManager(
            db_url="sqlite:///" + tempfile.mktemp(suffix=".db"),
            run_dir=tempfile.mkdtemp(),
            batching_interval=0,
            exit_event=threading.Event(),
        )
        calls = {"priority": 0, "worker": 0}

        def staged_batch(msg_queue):
            if msg_queue is manager.pending_priority_queue:
                calls["priority"] += 1
                return [(MessageType.TASK_INFO, task)] if calls["priority"] == 2 else []
            if msg_queue is manager.pending_worker_task_queue:
                calls["worker"] += 1
                if calls["worker"] == 1:
                    return [last]
                if calls["worker"] == 2:
                    threading.Timer(0.02, manager._kill_event.set).start()
                return []
            return []

        manager._get_messages_in_batch = staged_batch
        thread = threading.Thread(target=manager.start, args=(EmptyResourceQueue(),))
        thread.start()
        thread.join(timeout=5)
        self.assertFalse(thread.is_alive())

        status_rows = manager.db.session.execute(manager.db.meta.tables[STATUS].select()).fetchall()
        try_rows = manager.db.session.execute(manager.db.meta.tables[TRY].select()).fetchall()
        task_rows = manager.db.session.execute(manager.db.meta.tables[TASK].select()).fetchall()

        # This records the current implementation's ordering weakness.  The
        # status row is visible even though its TRY row did not exist yet.
        self.assertEqual(len(status_rows), 1)
        self.assertEqual(len(try_rows), 1)
        self.assertEqual(len(task_rows), 1)
        self.assertEqual(status_rows[0].task_status_name, "running_ended")


if __name__ == "__main__":
    unittest.main()
