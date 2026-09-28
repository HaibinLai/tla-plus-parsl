"""Runtime probes for MPI resource-specification validation and derivation."""

import unittest

from parsl.executors.errors import InvalidResourceSpecification
from parsl.executors.high_throughput.mpi_prefix_composer import validate_resource_spec


class MpiSpecRuntimeTest(unittest.TestCase):
    def test_empty_specification_is_rejected(self):
        with self.assertRaises(InvalidResourceSpecification):
            validate_resource_spec({})

    def test_zero_nodes_with_num_ranks_reproduces_division_error(self):
        with self.assertRaises(ZeroDivisionError):
            validate_resource_spec({"num_nodes": "0", "num_ranks": "1"})

    def test_positive_nodes_derive_missing_num_ranks(self):
        resource_spec = {"num_nodes": "2", "ranks_per_node": "3"}

        validate_resource_spec(resource_spec)

        self.assertEqual(resource_spec["num_ranks"], "6")


if __name__ == "__main__":
    unittest.main()
