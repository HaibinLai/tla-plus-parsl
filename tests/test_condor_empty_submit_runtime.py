"""Runtime probe for an empty successful HTCondor submit response."""

import unittest

from parsl.providers.condor.condor import CondorProvider
from parsl.providers.errors import ScaleOutFailed


class CondorEmptySubmitRuntimeTest(unittest.TestCase):
    def _provider(self):
        provider = CondorProvider.__new__(CondorProvider)
        provider.script_dir = "/tmp"
        provider.nodes_per_block = 1
        provider.scheduler_options = ""
        provider.worker_init = ""
        provider.environment = {}
        provider.project = ""
        provider.requirements = ""
        provider.transfer_input_files = []
        provider.mem_per_slot = None
        provider.cores_per_slot = None
        provider.resources = {}
        provider._write_submit_script = lambda *args, **kwargs: None
        provider.execute_wait = lambda command: (0, "", "")
        provider.launcher = lambda *args: "worker"
        return provider

    def test_empty_success_stdout_leaks_index_error_currently(self):
        provider = self._provider()
        with self.assertRaises(IndexError):
            provider.submit("worker", tasks_per_node=1)
        self.assertEqual(provider.resources, {})

    def test_candidate_fix_converts_empty_response_to_submission_failure(self):
        provider = self._provider()

        def fixed_submit(*args, **kwargs):
            retcode, stdout, stderr = provider.execute_wait("condor_submit")
            if retcode == 0 and not stdout.strip():
                raise ScaleOutFailed("condor", "successful submit returned no job ID")
            return provider.submit(*args, **kwargs)

        with self.assertRaises(ScaleOutFailed):
            fixed_submit("worker", tasks_per_node=1)
        self.assertEqual(provider.resources, {})


if __name__ == "__main__":
    unittest.main()
