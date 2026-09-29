"""Runtime probe for partial FTP stage-in output."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.ftp import _ftp_stage_in


class FailingFTP:
    def __init__(self, host):
        self.host = host

    def login(self):
        pass

    def cwd(self, path):
        pass

    def retrbinary(self, command, callback):
        callback(b"partial")
        raise OSError("FTP connection reset")

    def quit(self):
        pass


class FTPPartialCleanupRuntimeTest(unittest.TestCase):
    def test_transfer_failure_leaves_partial_destination_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("ftp://example.invalid/input.bin")
            file_obj.local_path = str(Path(directory) / "input.bin")

            with patch("parsl.data_provider.ftp.ftplib.FTP", FailingFTP):
                with self.assertRaises(OSError):
                    _ftp_stage_in(directory, outputs=[file_obj])

            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"partial")


if __name__ == "__main__":
    unittest.main()
