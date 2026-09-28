"""Runtime probe for FTP connection cleanup after transfer failure."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.ftp import in_task_transfer_wrapper


class FakeFTP:
    instances = []

    def __init__(self, host):
        self.host = host
        self.quit_calls = 0
        self.__class__.instances.append(self)

    def login(self):
        pass

    def cwd(self, path):
        pass

    def retrbinary(self, command, callback):
        raise OSError("transfer interrupted")

    def quit(self):
        self.quit_calls += 1


class FTPConnectionCleanupRuntimeTest(unittest.TestCase):
    def test_transfer_failure_leaves_ftp_connection_open_currently(self):
        FakeFTP.instances = []
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("ftp://host.example/input.bin")
            file_obj.local_path = str(Path(directory) / "input.bin")
            wrapped = in_task_transfer_wrapper(lambda: "app", file_obj, directory)

            with patch("parsl.data_provider.ftp.ftplib.FTP", FakeFTP):
                with self.assertRaises(OSError):
                    wrapped()

        self.assertEqual(len(FakeFTP.instances), 1)
        self.assertEqual(FakeFTP.instances[0].quit_calls, 0)


if __name__ == "__main__":
    unittest.main()
