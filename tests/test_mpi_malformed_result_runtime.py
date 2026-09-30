"""Runtime probe for MPI scheduler cleanup after corrupt result decoding."""

import pickle
import types
import unittest

from parsl.executors.high_throughput.mpi_resource_management import MPITaskScheduler


class CorruptResultQueue:
    def get(self, block=True, timeout=None):
        return b"not-a-pickle"


class MpiMalformedResultRuntimeTest(unittest.TestCase):
    def test_corrupt_result_leaves_allocated_nodes_and_no_terminal_result(self):
        scheduler = MPITaskScheduler.__new__(MPITaskScheduler)
        scheduler.pending_result_q = CorruptResultQueue()
        scheduler._map_tasks_to_nodes = {"task-1": ["node-a", "node-b"]}
        scheduler._free_node_counter = types.SimpleNamespace(value=0)

        with self.assertRaises(pickle.UnpicklingError):
            scheduler.get_result()

        self.assertEqual(scheduler._free_node_counter.value, 0)
        self.assertIn("task-1", scheduler._map_tasks_to_nodes)


if __name__ == "__main__":
    unittest.main()
