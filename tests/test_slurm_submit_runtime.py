"""Runtime probes for Slurm sbatch output and custom job-id regex handling."""

import tempfile
import unittest

from parsl.jobs.states import JobState
from parsl.providers.errors import SubmitException
from parsl.providers.slurm.slurm import SlurmProvider


class SlurmSubmitRuntimeTest(unittest.TestCase):
    def provider_with(self, output, regex=r"Submitted batch job (?P<id>\S*)"):
        provider = SlurmProvider.__new__(SlurmProvider)
        provider.resources = {}
        provider.script_dir = None
        provider.nodes_per_block = 1
        provider.walltime = "00:10:00"
        provider.scheduler_options = ""
        provider.worker_init = ""
        provider.mem_per_node = None
        provider.cores_per_node = None
        provider.regex_job_id = regex
        provider.launcher = lambda command, tasks_per_node, nodes, script_dir: command
        provider.execute_wait = lambda command: (0, output, "")
        provider._write_submit_script = lambda template, path, job_name, configs: None
        return provider

    def test_valid_output_registers_pending_job(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with("Submitted batch job 42\n")
            provider.script_dir = directory
            result = provider.submit("echo worker", tasks_per_node=1)
            self.assertEqual(result, "42")
            self.assertEqual(provider.resources["42"]["status"].state, JobState.PENDING)

    def test_empty_output_is_submit_exception(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with("")
            provider.script_dir = directory
            with self.assertRaises(SubmitException):
                provider.submit("echo worker", tasks_per_node=1)
            self.assertEqual(provider.resources, {})

    def test_matching_regex_without_named_id_raises_current_index_error(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = self.provider_with("JOB-7\n", regex=r"JOB-(\d+)")
            provider.script_dir = directory
            with self.assertRaises(IndexError):
                provider.submit("echo worker", tasks_per_node=1)
            self.assertEqual(provider.resources, {})


if __name__ == "__main__":
    unittest.main()
