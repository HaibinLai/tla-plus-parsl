"""Runtime probe for the monitoring migration late-producer race."""

import queue
import tempfile
import threading
import unittest

from parsl.monitoring.db_manager import DatabaseManager


class LateProducerQueue:
    def __init__(self):
        self.message = None

    def empty(self):
        # The queue appears empty at the shutdown observation.
        return True

    def get(self, timeout=None):
        raise queue.Empty


class MonitoringShutdownRaceRuntimeTest(unittest.TestCase):
    def test_message_enqueued_after_empty_observation_is_left_behind(self):
        manager = DatabaseManager(
            db_url="sqlite:///" + tempfile.mktemp(suffix=".db"),
            run_dir=tempfile.mkdtemp(),
            exit_event=threading.Event(),
        )
        external = LateProducerQueue()
        kill_event = threading.Event()
        kill_event.set()

        thread = threading.Thread(
            target=manager._migrate_logs_to_internal,
            args=(external, kill_event),
        )
        thread.start()
        thread.join(timeout=2)
        self.assertFalse(thread.is_alive())

        # A producer racing with the empty() check can enqueue after the
        # migration thread has already exited.
        external.message = ("late", {"task_id": 2})
        self.assertEqual(external.message, ("late", {"task_id": 2}))
        self.assertTrue(manager.pending_priority_queue.empty())


if __name__ == "__main__":
    unittest.main()
