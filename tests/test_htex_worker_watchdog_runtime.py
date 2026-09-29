"""Runtime probe for HTEX worker-loss recovery."""

import pickle
import threading
import unittest

from parsl.executors.high_throughput import process_worker_pool as pool


class FakeStopEvent:
    def __init__(self):
        self.wait_calls = 0

    def wait(self, _period):
        self.wait_calls += 1
        return self.wait_calls > 1


class FakeProcess:
    def is_alive(self):
        return False


class HtexWorkerWatchdogRuntimeTest(unittest.TestCase):
    def test_busy_worker_death_enqueues_worker_lost_result(self):
        manager = pool.Manager.__new__(pool.Manager)
        manager._stop_event = FakeStopEvent()
        manager.heartbeat_period = 1
        manager._tasks_in_progress = {3: {"task_id": "logical-3"}}
        queued = []
        manager.pending_result_queue = type("Queue", (), {"put": queued.append})()
        restarted = []
        manager._start_worker = lambda worker_id: restarted.append(worker_id) or object()

        processes = {3: FakeProcess()}
        manager.worker_watchdog(processes)

        self.assertEqual(restarted, [3])
        self.assertIsNotNone(processes[3])
        self.assertEqual(manager._tasks_in_progress, {})
        self.assertEqual(len(queued), 1)

        message = pickle.loads(queued[0])
        self.assertEqual(message["type"], "result")
        self.assertEqual(message["task_id"], "logical-3")
        self.assertIn("exception", message)


if __name__ == "__main__":
    unittest.main()
