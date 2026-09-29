"""Runtime probe for Torque tasks_per_node admission."""

import unittest

from parsl.providers.torque.torque import TorqueProvider


class RecordingLauncher:
    def __init__(self):
        self.args = None

    def __call__(self, *args):
        self.args = args
        return "wrapped"


class TorqueTasksPerNodeRuntimeTest(unittest.TestCase):
    def test_negative_tasks_per_node_reaches_launcher_currently(self):
        provider = TorqueProvider(nodes_per_block=2, init_blocks=0)
        provider.script_dir = "/tmp"
        launcher = RecordingLauncher()
        provider.launcher = launcher
        provider._write_submit_script = lambda *args, **kwargs: None
        provider.execute_wait = lambda command: (1, "", "")

        self.assertIsNone(provider.submit("echo task", -1))
        self.assertEqual(launcher.args[1], -1)


if __name__ == "__main__":
    unittest.main()
