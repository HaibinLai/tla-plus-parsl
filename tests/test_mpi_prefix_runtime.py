"""Runtime probes for MPI launch-prefix selection."""

import unittest

from parsl.executors.high_throughput.mpi_prefix_composer import compose_all


class MpiPrefixRuntimeTest(unittest.TestCase):
    def test_mpiexec_prefix_is_selected_and_contains_hosts(self):
        prefixes = compose_all(
            "mpiexec",
            {"num_ranks": "4", "ranks_per_node": "2", "launcher_options": "--bind-to core"},
            ["node-a", "node-b"],
        )

        self.assertEqual(prefixes["PARSL_MPI_PREFIX"], prefixes["PARSL_MPIEXEC_PREFIX"])
        self.assertIn("mpiexec", prefixes["PARSL_MPI_PREFIX"])
        self.assertIn("node-a,node-b", prefixes["PARSL_MPI_PREFIX"])

    def test_srun_and_aprun_select_their_own_prefixes(self):
        spec = {"num_ranks": "2", "ranks_per_node": "1"}
        for launcher, marker in (("srun", "PARSL_SRUN_PREFIX"), ("aprun", "PARSL_APRUN_PREFIX")):
            with self.subTest(launcher=launcher):
                prefixes = compose_all(launcher, spec, ["node-a"])
                self.assertEqual(prefixes["PARSL_MPI_PREFIX"], prefixes[marker])

    def test_unknown_launcher_is_rejected(self):
        with self.assertRaises(RuntimeError):
            compose_all("unknown", {"num_ranks": "1", "ranks_per_node": "1"}, ["node-a"])


if __name__ == "__main__":
    unittest.main()
