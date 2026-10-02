import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.ftp import in_task_transfer_wrapper


class _FailingFTP:
    instances = []

    def __init__(self, host):
        self.quit_calls = 0
        self.__class__.instances.append(self)

    def login(self):
        return None

    def cwd(self, _path):
        return None

    def retrbinary(self, _command, callback):
        callback(b"partial-input")
        raise OSError("connection dropped")

    def quit(self):
        self.quit_calls += 1


class FTPInTaskTransferGateRuntimeTest(unittest.TestCase):
    def test_failed_transfer_publishes_partial_bytes_and_leaves_connection_open(self):
        _FailingFTP.instances = []
        calls = []
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("ftp://server/data/input.txt")
            file_obj.local_path = str(Path(directory) / "input.txt")
            wrapped = in_task_transfer_wrapper(lambda: calls.append("app"), file_obj, directory)

            with patch("parsl.data_provider.ftp.ftplib.FTP", _FailingFTP):
                with self.assertRaises(OSError):
                    wrapped()

            self.assertEqual(calls, [])
            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"partial-input")
            self.assertEqual(_FailingFTP.instances[0].quit_calls, 0)


if __name__ == "__main__":
    unittest.main()
