"""Runtime probe for bash_app timeout process cleanup."""

import subprocess
import unittest
from unittest.mock import patch

from parsl.app.bash import remote_side_bash_executor
from parsl.app.errors import AppTimeout


class TimeoutProcess:
    def __init__(self):
        self.kill_calls = 0
        self.returncode = None

    def wait(self, timeout=None):
        raise subprocess.TimeoutExpired(cmd="sleep 1", timeout=timeout)

    def kill(self):
        self.kill_calls += 1
        self.returncode = -9


class BashTimeoutCleanupRuntimeTest(unittest.TestCase):
    def test_timeout_raises_without_killing_current_shell(self):
        process = TimeoutProcess()

        def command(**kwargs):
            return "sleep 1"

        with patch("subprocess.Popen", return_value=process):
            with self.assertRaises(AppTimeout):
                remote_side_bash_executor(command, walltime=1)

        self.assertEqual(process.kill_calls, 0)
        self.assertIsNone(process.returncode)


if __name__ == "__main__":
    unittest.main()
