"""Runtime probe for multiple deferred first-worker observations."""

import datetime
import queue
import tempfile
import threading
import unittest

from parsl.monitoring.db_manager import DatabaseManager, STATUS, TRY
from parsl.monitoring.message_type import MessageType


class EmptyResourceQueue:
    def empty(self):
        return True

    def get(self, timeout=None):
        raise queue.Empty


class MonitoringDeferredMultiplicityRuntimeTest(unittest.TestCase):
    def test_second_deferred_first_message_replaces_the_first_currently(self):
        now = datetime.datetime.now()
        task = {
            "task_id": 7,
            "try_id": 0,
            "run_id": "run-deferred-multiplicity",
            "task_func_name": "work",
            "task_memoize": "false",
            "task_fail_count": 0,
            "task_fail_cost": 0.0,
            "task_executor": "local",
            "timestamp": now,
        }
        first = {
            "task_id": 7,
            "try_id": 0,
            "run_id": "run-deferred-multiplicity",
            "first_msg": True,
            "last_msg": False,
            "timestamp": now + datetime.timedelta(seconds=1),
            "block_id": "local-0",
            "hostname": "worker-a",
        }
        second = dict(first)
        second["timestamp"] = first["timestamp"] + datetime.timedelta(seconds=1)
        second["hostname"] = "worker-b"

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
                    return [first, second]
                if calls["worker"] == 2:
                    threading.Timer(0.02, manager._kill_event.set).start()
                return []
            return []

        manager._get_messages_in_batch = staged_batch
        thread = threading.Thread(target=manager.start, args=(EmptyResourceQueue(),))
        thread.start()
        thread.join(timeout=5)
        self.assertFalse(thread.is_alive())

        rows = manager.db.session.execute(manager.db.meta.tables[STATUS].select()).fetchall()
        try_rows = manager.db.session.execute(manager.db.meta.tables[TRY].select()).fetchall()
        self.assertEqual(len(rows), 1)
        self.assertEqual(try_rows[0].hostname, "worker-b")


if __name__ == "__main__":
    unittest.main()
