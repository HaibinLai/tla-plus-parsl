"""Runtime probe for an empty successful Grid Engine submit response."""

import unittest

from parsl.providers.grid_engine.grid_engine import GridEngineProvider


class GridEngineEmptySubmitRuntimeTest(unittest.TestCase):
    def test_empty_success_stdout_returns_none_currently(self):
        provider = GridEngineProvider.__new__(GridEngineProvider)
        provider.script_dir = "/tmp"
        provider.nodes_per_block = 1
        provider.scheduler_options = ""
        provider.worker_init = ""
        provider.queue = None
        provider.resources = {}
        provider.get_configs = lambda command, tasks_per_node: {}
        provider._write_submit_script = lambda *args, **kwargs: None
        provider.execute_wait = lambda command: (0, "", "")

        self.assertIsNone(provider.submit("worker", tasks_per_node=1))
        self.assertEqual(provider.resources, {})


if __name__ == "__main__":
    unittest.main()
