"""Runtime probe for HTTP staging's missing status-code validation."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.http import in_task_transfer_wrapper


class ErrorResponse:
    status_code = 404

    def iter_content(self, chunk_size):
        yield b"not found"


class HTTPStatusValidationRuntimeTest(unittest.TestCase):
    def test_non_2xx_body_is_published_and_task_runs_currently(self):
        calls = []
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("https://example.invalid/missing.txt")
            file_obj.local_path = str(Path(directory) / "missing.txt")
            wrapped = in_task_transfer_wrapper(
                lambda: calls.append("task") or "result", file_obj, directory
            )

            with patch("parsl.data_provider.http.requests.get", return_value=ErrorResponse()):
                self.assertEqual(wrapped(), "result")

            self.assertEqual(calls, ["task"])
            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"not found")


if __name__ == "__main__":
    unittest.main()
