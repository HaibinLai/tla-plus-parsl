"""Runtime probe for HTTP response cleanup after a stream failure."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.http import in_task_transfer_wrapper


class FailingResponse:
    def __init__(self):
        self.closed = False

    def iter_content(self, chunk_size):
        yield b"partial-http"
        raise OSError("connection dropped")

    def close(self):
        self.closed = True


class HTTPConnectionCleanupRuntimeTest(unittest.TestCase):
    def test_stream_failure_leaves_response_open_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            response = FailingResponse()
            file_obj = File("http://server/data/input.txt")
            file_obj.local_path = str(Path(directory) / "input.txt")
            wrapped = in_task_transfer_wrapper(lambda: None, file_obj, directory)

            with patch("parsl.data_provider.http.requests.get", return_value=response):
                with self.assertRaises(OSError):
                    wrapped()

            self.assertFalse(response.closed)
            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"partial-http")


if __name__ == "__main__":
    unittest.main()
