"""Runtime probe for Slurm zero tasks_per_node admission."""

import unittest

from parsl.providers.slurm.slurm import SlurmProvider


class SlurmTasksPerNodeRuntimeTest(unittest.TestCase):
    def test_zero_tasks_per_node_reaches_division_currently(self):
        provider = SlurmProvider.__new__(SlurmProvider)
        provider.scheduler_options = ""
        provider.worker_init = ""
        provider.mem_per_node = None
        provider.cores_per_node = 4

        with self.assertRaises(ZeroDivisionError):
            provider.submit("echo worker", tasks_per_node=0)


if __name__ == "__main__":
    unittest.main()
