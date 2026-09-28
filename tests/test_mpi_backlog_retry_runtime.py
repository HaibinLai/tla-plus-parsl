"""Runtime probe for MPI backlog recursion when resources remain unavailable."""

import queue
import unittest

from parsl.executors.high_throughput.mpi_resource_management import (
    MPITaskScheduler,
    PrioritizedTask,
)
from parsl.multiprocessing import SpawnContext


class PendingTaskQueue:
    def put(self, task):
        return None


class MpiBacklogRetryRuntimeTest(unittest.TestCase):
    def test_unavailable_backlog_head_recurses_until_recursion_error(self):
        scheduler = MPITaskScheduler.__new__(MPITaskScheduler)
        scheduler._backlog_queue = queue.PriorityQueue()
        scheduler._backlog_queue.put(PrioritizedTask(2, {
            "task_id": 7,
            "context": {"resource_spec": {"num_nodes": 2}},
        }))
        scheduler._free_node_counter = SpawnContext.Value("i", 1)
        scheduler.nodes_q = queue.Queue()
        scheduler.nodes_q.put("node-a")
        scheduler._map_tasks_to_nodes = {}
        scheduler.pending_task_q = PendingTaskQueue()

        with self.assertRaises(RecursionError):
            scheduler._schedule_backlog_tasks()


if __name__ == "__main__":
    unittest.main()
