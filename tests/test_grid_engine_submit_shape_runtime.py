"""Runtime probe for Grid Engine submit-response identifier validation."""

import unittest

from parsl.providers.grid_engine.grid_engine import GridEngineProvider


class GridEngineSubmitShapeRuntimeTest(unittest.TestCase):
    def test_malformed_success_line_is_published_as_job_id_currently(self):
        provider = GridEngineProvider.__new__(GridEngineProvider)
        provider.script_dir = "/tmp"
        provider.nodes_per_block = 1
        provider.scheduler_options = ""
        provider.worker_init = ""
        provider.queue = None
        provider.resources = {}
        provider.get_configs = lambda command, tasks_per_node: {}
        provider._write_submit_script = lambda *args, **kwargs: None
        provider.execute_wait = lambda command: (0, "warning without a scheduler id\n", "")

        job_id = provider.submit("worker", tasks_per_node=1)

        self.assertEqual(job_id, "warning without a scheduler id")
        self.assertIn(job_id, provider.resources)


if __name__ == "__main__":
    unittest.main()
