"""Runtime probe for RSync partial destination cleanup."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.rsync import in_task_stage_in_wrapper


class RSyncPartialCleanupRuntimeTest(unittest.TestCase):
    def test_failed_rsync_leaves_partial_destination_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "input.txt"
            destination.write_bytes(b"partial")
            file_obj = File("/remote/input.txt")
            file_obj.local_path = str(destination)
            wrapped = in_task_stage_in_wrapper(lambda: "unused", file_obj, "", "submit-host")

            with patch("parsl.data_provider.rsync.os.system", return_value=1):
                with self.assertRaises(RuntimeError):
                    wrapped()

            self.assertTrue(destination.exists())
            self.assertEqual(destination.read_bytes(), b"partial")


if __name__ == "__main__":
    unittest.main()
