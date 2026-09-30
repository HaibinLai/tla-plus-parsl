"""Runtime probe for Torque multi-line submit-response registration."""

import tempfile
import unittest

from parsl.providers.torque.torque import TorqueProvider


class TorqueSubmitShapeRuntimeTest(unittest.TestCase):
    def test_multiple_success_lines_publish_multiple_resources_currently(self):
        provider = TorqueProvider()
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        provider.script_dir = directory.name
        provider.launcher = lambda command, tasks_per_node, nodes, script_dir: command
        provider._write_submit_script = lambda *args, **kwargs: None
        provider.execute_wait = lambda command: (0, "first\nsecond\n", "")

        self.assertEqual(provider.submit("echo worker", tasks_per_node=1), "second")
        self.assertEqual(set(provider.resources), {"first", "second"})


if __name__ == "__main__":
    unittest.main()
