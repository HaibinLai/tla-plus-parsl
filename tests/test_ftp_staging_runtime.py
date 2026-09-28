"""Runtime probe for FTP in-task staging partial-file cleanup."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.ftp import in_task_transfer_wrapper


class FailingFTP:
    def __init__(self, host):
        self.host = host

    def login(self):
        return None

    def cwd(self, path):
        return None

    def retrbinary(self, command, callback):
        callback(b"partial-input")
        raise OSError("connection dropped")

    def quit(self):
        return None


class FTPStagingRuntimeTest(unittest.TestCase):
    def test_failed_transfer_leaves_partial_file_currently(self):
        calls = []
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("ftp://server/data/input.txt")
            file_obj.local_path = str(Path(directory) / "input.txt")
            wrapped = in_task_transfer_wrapper(
                lambda: calls.append("app"), file_obj, directory
            )

            with patch("parsl.data_provider.ftp.ftplib.FTP", FailingFTP):
                with self.assertRaises(OSError):
                    wrapped()

            self.assertEqual(calls, [])
            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"partial-input")


if __name__ == "__main__":
    unittest.main()
