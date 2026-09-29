"""Runtime probe for LocalProvider failed-launch script cleanup."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.providers.local.local import LocalProvider


class LocalProviderSubmitCleanupRuntimeTest(unittest.TestCase):
    def test_failed_launch_leaves_submit_script_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = LocalProvider()
            provider.script_dir = directory
            provider.launcher = lambda command, tasks_per_node, nodes, script_dir: command

            with patch(
                "parsl.providers.local.local.execute_wait",
                return_value=(1, "", "launch failed"),
            ):
                with self.assertRaises(Exception):
                    provider.submit("echo worker", tasks_per_node=1)

            scripts = list(Path(directory).glob("*.sh"))
            self.assertEqual(len(scripts), 1)


if __name__ == "__main__":
    unittest.main()
