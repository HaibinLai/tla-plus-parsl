"""Runtime probes for DatabaseManager's deferred worker-message path."""

import datetime
import queue
import tempfile
import threading
import time
import unittest

from parsl.monitoring.db_manager import DatabaseManager, STATUS, TASK, TRY
from parsl.monitoring.message_type import MessageType


class EmptyResourceQueue:
    def empty(self):
        return True

    def get(self, timeout=None):
        raise queue.Empty


class MonitoringDeferredRuntimeTest(unittest.TestCase):
    def make_messages(self):
        now = datetime.datetime.now()
        task = {
            "task_id": 7,
            "try_id": 0,
            "run_id": "run-deferred",
            "task_func_name": "work",
            "task_memoize": "false",
            "task_fail_count": 0,
            "task_fail_cost": 0.0,
            "task_executor": "local",
            "timestamp": now,
        }
        worker = {
            "task_id": 7,
            "try_id": 0,
            "run_id": "run-deferred",
            "first_msg": True,
            "last_msg": False,
            "timestamp": now + datetime.timedelta(seconds=1),
            "block_id": "local-0",
            "hostname": "worker-a",
        }
        return task, worker

    def run_staged(self, worker_messages):
        db_path = tempfile.mktemp(suffix=".db")
        manager = DatabaseManager(
            db_url="sqlite:///" + db_path,
            run_dir=tempfile.mkdtemp(),
            batching_interval=0,
            exit_event=threading.Event(),
        )
        task, _ = self.make_messages()
        calls = {"priority": 0, "worker": 0}

        def staged_batch(msg_queue):
            if msg_queue is manager.pending_priority_queue:
                calls["priority"] += 1
                if calls["priority"] == 2:
                    return [(MessageType.TASK_INFO, task)]
                return []
            if msg_queue is manager.pending_worker_task_queue:
                calls["worker"] += 1
                if calls["worker"] == 1:
                    return list(worker_messages)
                if calls["worker"] == 2:
                    # The second iteration replays the deferred message after
                    # TASK_INFO has inserted the try row.
                    threading.Timer(0.02, manager._kill_event.set).start()
                return []
            return []

        manager._get_messages_in_batch = staged_batch
        thread = threading.Thread(target=manager.start, args=(EmptyResourceQueue(),))
        thread.start()
        thread.join(timeout=5)
        self.assertFalse(thread.is_alive(), "DatabaseManager did not drain staged messages")

        rows = manager.db.session.execute(manager.db.meta.tables[TRY].select()).fetchall()
        status_rows = manager.db.session.execute(manager.db.meta.tables[STATUS].select()).fetchall()
        task_rows = manager.db.session.execute(manager.db.meta.tables[TASK].select()).fetchall()
        return rows, status_rows, task_rows

    def test_first_worker_message_is_deferred_then_replayed(self):
        try_rows, status_rows, task_rows = self.run_staged(self.make_messages()[1:])
        self.assertEqual(len(task_rows), 1)
        self.assertEqual(len(try_rows), 1)
        self.assertEqual([row.task_status_name for row in status_rows], ["running"])
        self.assertEqual(try_rows[0].hostname, "worker-a")

    def test_duplicate_deferred_message_keeps_latest_observation(self):
        _, first = self.make_messages()
        second = dict(first)
        second["timestamp"] = first["timestamp"] + datetime.timedelta(seconds=1)
        second["hostname"] = "worker-b"
        _, status_rows, _ = self.run_staged([first, second])
        self.assertEqual(len(status_rows), 1)
        self.assertEqual(status_rows[0].timestamp, second["timestamp"])


if __name__ == "__main__":
    unittest.main()
