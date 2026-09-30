"""Runtime probe for an HTEX watchdog restart exception escaping the loop."""

import multiprocessing
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


class HtexWorkerRestartFailureRuntimeTest(unittest.TestCase):
    def test_restart_exception_escapes_watchdog_currently(self):
        manager = pool.Manager.__new__(pool.Manager)
        manager._stop_event = OneCycleStopEvent()
        manager.heartbeat_period = 1
        manager._tasks_in_progress = {7: {"task_id": "logical-7"}}
        manager.pending_result_queue = multiprocessing.Queue()
        manager._start_worker = lambda _worker_id: (_ for _ in ()).throw(
            RuntimeError("spawn failed"))

        with self.assertRaises(RuntimeError):
            manager.worker_watchdog({7: DeadProcess()})


if __name__ == "__main__":
    unittest.main()
