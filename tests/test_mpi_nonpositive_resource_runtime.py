"""Runtime probes for non-positive MPI resource admission."""

import unittest

from parsl.executors.high_throughput.mpi_prefix_composer import validate_resource_spec


class MpiNonPositiveResourceRuntimeTest(unittest.TestCase):
    def test_nonpositive_counts_are_currently_accepted(self):
        cases = (
            {"num_nodes": "0", "num_ranks": "1"},
            {"num_nodes": "-1", "num_ranks": "2"},
            {"num_nodes": "2", "num_ranks": "0"},
            {"num_nodes": "2", "num_ranks": "-1"},
            {"num_nodes": "2", "ranks_per_node": "0"},
            {"num_nodes": "2", "ranks_per_node": "-1"},
        )

        for resource_spec in cases:
            with self.subTest(resource_spec=resource_spec):
                candidate = dict(resource_spec)
                try:
                    validate_resource_spec(candidate)
                except Exception as exc:
                    # Zero nodes currently raises during derivation; that is
                    # still a raw arithmetic failure rather than validation.
                    self.assertIsInstance(exc, ZeroDivisionError)
                else:
                    self.assertTrue(
                        any(float(candidate.get(key, "1")) <= 0
                            for key in ("num_nodes", "num_ranks", "ranks_per_node")),
                        candidate,
                    )


if __name__ == "__main__":
    unittest.main()
