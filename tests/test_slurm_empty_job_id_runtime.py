"""Runtime probe for Slurm's empty captured job identifier."""

import tempfile
import unittest

from parsl.providers.slurm.slurm import SlurmProvider


class SlurmEmptyJobIdRuntimeTest(unittest.TestCase):
    def test_empty_captured_job_id_is_registered_currently(self):
        provider = SlurmProvider.__new__(SlurmProvider)
        provider.resources = {}
        provider.script_dir = None
        provider.nodes_per_block = 1
        provider.walltime = "00:10:00"
        provider.scheduler_options = ""
        provider.worker_init = ""
        provider.mem_per_node = None
        provider.cores_per_node = None
        provider.regex_job_id = r"Submitted batch job (?P<id>\S*)"
        provider.launcher = lambda command, tasks_per_node, nodes, script_dir: command
        provider.execute_wait = lambda command: (0, "Submitted batch job \n", "")
        provider._write_submit_script = lambda *args, **kwargs: None

        with tempfile.TemporaryDirectory() as directory:
            provider.script_dir = directory
            self.assertEqual(provider.submit("echo worker", tasks_per_node=1), "")

        self.assertIn("", provider.resources)


if __name__ == "__main__":
    unittest.main()
