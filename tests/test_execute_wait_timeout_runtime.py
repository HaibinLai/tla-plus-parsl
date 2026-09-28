"""Runtime probe for scheduler-command timeout cleanup."""

import subprocess
import unittest
from unittest.mock import patch

from parsl.utils import execute_wait


class FakeProcess:
    def __init__(self):
        self.pid = 4242
        self.returncode = None
        self.kill_calls = 0
        self.terminate_calls = 0

    def communicate(self, timeout=None):
        raise subprocess.TimeoutExpired("scheduler-command", timeout)


class ExecuteWaitTimeoutRuntimeTest(unittest.TestCase):
    def test_timeout_reraises_without_terminating_process_currently(self):
        process = FakeProcess()
        with patch("parsl.utils.subprocess.Popen", return_value=process):
            with self.assertRaises(subprocess.TimeoutExpired):
                execute_wait("sleep 60", walltime=1)

        self.assertEqual(process.kill_calls, 0)
        self.assertEqual(process.terminate_calls, 0)
        self.assertIsNone(process.returncode)


if __name__ == "__main__":
    unittest.main()
