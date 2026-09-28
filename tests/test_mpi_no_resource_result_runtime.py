"""Runtime probe for MPI results without a node-allocation map entry."""

import pickle
import unittest

from parsl.executors.high_throughput.mpi_resource_management import MPITaskScheduler


class OneResultQueue:
    def __init__(self, payload):
        self.payload = payload

    def get(self, block=True, timeout=None):
        return self.payload


class MpiNoResourceResultRuntimeTest(unittest.TestCase):
    def test_unmapped_result_hits_current_assertion(self):
        scheduler = MPITaskScheduler.__new__(MPITaskScheduler)
        scheduler.pending_result_q = OneResultQueue(pickle.dumps({"type": "result", "task_id": 9}))
        scheduler._map_tasks_to_nodes = {}

        with self.assertRaises(AssertionError):
            scheduler.get_result()


if __name__ == "__main__":
    unittest.main()
