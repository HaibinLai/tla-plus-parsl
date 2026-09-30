"""Runtime probe for malformed MPI task context admission."""

import unittest
from unittest.mock import Mock

from parsl.executors.high_throughput.mpi_resource_management import MPITaskScheduler


class MpiTaskContextShapeRuntimeTest(unittest.TestCase):
    def test_non_mapping_context_exposes_attribute_error_currently(self):
        scheduler = MPITaskScheduler.__new__(MPITaskScheduler)
        scheduler.pending_task_q = Mock()

        with self.assertRaises(AttributeError):
            scheduler.put_task({"task_id": 7, "context": []})

        scheduler.pending_task_q.put.assert_not_called()


if __name__ == "__main__":
    unittest.main()
