"""Runtime probe for MPI ranks-per-node derivation."""

import unittest

from parsl.executors.high_throughput.mpi_prefix_composer import (
    compose_mpiexec_launch_cmd,
    validate_resource_spec,
)


class MpiNonDivisibleRuntimeTest(unittest.TestCase):
    def test_nondivisible_ranks_are_emitted_as_fractional_ppn_currently(self):
        resource_spec = {"num_nodes": "2", "num_ranks": "5"}
        validate_resource_spec(resource_spec)

        self.assertEqual(resource_spec["ranks_per_node"], "2.5")
        _, command = compose_mpiexec_launch_cmd(resource_spec, ["node-a", "node-b"])
        self.assertIn("-ppn 2.5", command)


if __name__ == "__main__":
    unittest.main()
