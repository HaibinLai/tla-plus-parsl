import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.http import in_task_transfer_wrapper


class _FailingResponse:
    def __init__(self):
        self.closed = False

    def iter_content(self, _chunk_size=None, **_kwargs):
        yield b"partial-http"
        raise OSError("connection dropped")

    def close(self):
        self.closed = True


class HTTPInTaskCleanupGateRuntimeTest(unittest.TestCase):
    def test_failed_stream_leaves_partial_bytes_and_response_open_currently(self):
        calls = []
        response = _FailingResponse()
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("http://server/data/input.txt")
            file_obj.local_path = str(Path(directory) / "input.txt")
            wrapped = in_task_transfer_wrapper(lambda: calls.append("app"), file_obj, directory)

            with patch("parsl.data_provider.http.requests.get", return_value=response):
                with self.assertRaises(OSError):
                    wrapped()

            self.assertEqual(calls, [])
            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"partial-http")
            self.assertFalse(response.closed)


if __name__ == "__main__":
    unittest.main()
