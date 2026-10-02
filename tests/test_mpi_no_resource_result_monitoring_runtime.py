"""Runtime bridge for MPI unmapped results and downstream terminal state."""

import pickle
import unittest
from concurrent.futures import Future

from parsl.executors.high_throughput.mpi_resource_management import MPITaskScheduler


class OneResultQueue:
    def get(self, block=True, timeout=None):
        return pickle.dumps({"type": "result", "task_id": 9})


class MpiNoResourceResultMonitoringRuntimeTest(unittest.TestCase):
    def test_scheduler_assertion_prevents_future_and_monitor_completion_currently(self):
        scheduler = MPITaskScheduler.__new__(MPITaskScheduler)
        scheduler.pending_result_q = OneResultQueue()
        scheduler._map_tasks_to_nodes = {}
        future = Future()
        monitoring = []

        with self.assertRaises(AssertionError):
            result = scheduler.get_result()
            future.set_result(result)
            monitoring.append("terminal")

        self.assertFalse(future.done())
        self.assertEqual(monitoring, [])


if __name__ == "__main__":
    unittest.main()
