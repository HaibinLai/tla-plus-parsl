"""Runtime probe for malformed LocalProvider launcher PID output."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.providers.local.local import LocalProvider


class LocalSubmitPidShapeRuntimeTest(unittest.TestCase):
    def test_successful_launcher_with_non_numeric_pid_raises_value_error_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = LocalProvider()
            provider.script_dir = directory
            with patch(
                "parsl.providers.local.local.execute_wait",
                return_value=(0, "PID:not-a-number\n", ""),
            ):
                with self.assertRaises(ValueError):
                    provider.submit("true", tasks_per_node=1)

            self.assertEqual(provider.resources, {})
            self.assertEqual(list(Path(directory).glob("*.sh")).__len__(), 1)


if __name__ == "__main__":
    unittest.main()
