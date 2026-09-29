"""Runtime probe for missing-file timeout behavior."""

import tempfile
import unittest
from pathlib import Path

from parsl.utils import time_limited_open


class TimeLimitedOpenTimeoutRuntimeTest(unittest.TestCase):
    def test_missing_file_exposes_raw_open_error_after_wait_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "not-created.txt"
            with self.assertRaises(FileNotFoundError):
                with time_limited_open(str(missing), "r", seconds=0):
                    pass


if __name__ == "__main__":
    unittest.main()
