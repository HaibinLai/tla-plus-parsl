"""Runtime probe for partial HTTP staging output after stream failure."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.http import in_task_transfer_wrapper


class FailingResponse:
    status_code = 200

    def iter_content(self, chunk_size):
        yield b"partial"
        raise OSError("connection reset")


class HTTPPartialCleanupRuntimeTest(unittest.TestCase):
    def test_stream_failure_leaves_partial_destination_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("https://example.invalid/input.bin")
            file_obj.local_path = str(Path(directory) / "input.bin")
            wrapped = in_task_transfer_wrapper(lambda: "app", file_obj, directory)

            with patch("parsl.data_provider.http.requests.get", return_value=FailingResponse()):
                with self.assertRaises(OSError):
                    wrapped()

            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"partial")


if __name__ == "__main__":
    unittest.main()
