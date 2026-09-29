"""Runtime probe for the HTEX watchdog/result publication race."""

import pickle
import unittest

from parsl.executors.high_throughput import process_worker_pool as pool


class OneCycleStopEvent:
    def __init__(self):
        self.calls = 0

    def wait(self, _period):
        self.calls += 1
        return self.calls > 1


class DeadProcess:
    def is_alive(self):
        return False


class HtexWatchdogResultRaceRuntimeTest(unittest.TestCase):
    def test_stale_worker_mapping_adds_worker_lost_after_result_is_queued(self):
        manager = pool.Manager.__new__(pool.Manager)
        manager._stop_event = OneCycleStopEvent()
        manager.heartbeat_period = 1
        manager._tasks_in_progress = {5: {"task_id": "logical-5"}}

        already_published = pickle.dumps(
            {"type": "result", "task_id": "logical-5", "result": b"success"}
        )
        queued = [already_published]
        manager.pending_result_queue = type("Queue", (), {"put": queued.append})()
        manager._start_worker = lambda worker_id: object()

        manager.worker_watchdog({5: DeadProcess()})

        self.assertEqual(len(queued), 2)
        first = pickle.loads(queued[0])
        second = pickle.loads(queued[1])
        self.assertIn("result", first)
        self.assertIn("exception", second)
        self.assertEqual(first["task_id"], second["task_id"])


if __name__ == "__main__":
    unittest.main()
