"""Runtime bridge for the joint HTTP status/length admission contract."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.http import in_task_transfer_wrapper


class InvalidResponse:
    status_code = 404
    headers = {"Content-Length": "5"}

    def iter_content(self, chunk_size):
        yield b"abc"


class HTTPInTaskAdmissionRuntimeTest(unittest.TestCase):
    def test_current_wrapper_admits_user_code_with_bad_status_and_short_body(self):
        calls = []
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("https://example.invalid/input")
            file_obj.local_path = str(Path(directory) / "input")
            wrapped = in_task_transfer_wrapper(
                lambda: calls.append("ran") or "result", file_obj, directory
            )

            with patch("parsl.data_provider.http.requests.get", return_value=InvalidResponse()):
                self.assertEqual(wrapped(), "result")

            self.assertEqual(calls, ["ran"])
            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"abc")


if __name__ == "__main__":
    unittest.main()
