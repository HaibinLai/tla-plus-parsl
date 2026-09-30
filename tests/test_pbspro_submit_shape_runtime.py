"""Runtime probe for PBS Pro multi-line qsub responses."""

import tempfile
import unittest
from unittest.mock import patch

from parsl.providers.pbspro.pbspro import PBSProProvider


class PbsproSubmitShapeRuntimeTest(unittest.TestCase):
    def test_multiple_success_stdout_lines_publish_multiple_resources_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = PBSProProvider.__new__(PBSProProvider)
            provider.script_dir = directory
            provider.queue = None
            provider.account = None
            provider.select_options = ""
            provider.nodes_per_block = 1
            provider.cpus_per_node = 1
            provider.walltime = "00:05:00"
            provider.scheduler_options = ""
            provider.worker_init = ""
            provider.template_string = "{user_script}"
            provider.launcher = lambda command, tasks, nodes, script_dir: command
            provider.resources = {}
            provider._write_submit_script = lambda *args: None

            with patch(
                "parsl.providers.pbspro.pbspro.time.time",
                return_value=1.0,
            ), patch(
                "parsl.providers.pbspro.pbspro.PBSProProvider.execute_wait",
                return_value=(0, "123.server\nwarning-line\n", ""),
            ):
                job_id = provider.submit("worker", tasks_per_node=1)

            self.assertEqual(job_id, "warning-line")
            self.assertEqual(set(provider.resources), {"123.server", "warning-line"})


if __name__ == "__main__":
    unittest.main()
