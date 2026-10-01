"""Runtime bridge for HTTP in-task response validation and task admission."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.http import in_task_transfer_wrapper


class NonSuccessResponse:
    status_code = 404

    def iter_content(self, chunk_size):
        yield b"error-body"


class HTTPInTaskTransferGateRuntimeTest(unittest.TestCase):
    def test_current_wrapper_runs_user_function_after_non_success_transfer(self):
        calls = []
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("https://example.invalid/input.bin")
            file_obj.local_path = str(Path(directory) / "input.bin")
            wrapped = in_task_transfer_wrapper(
                lambda: calls.append("ran") or "result", file_obj, directory
            )

            with patch("parsl.data_provider.http.requests.get", return_value=NonSuccessResponse()):
                self.assertEqual(wrapped(), "result")

            self.assertEqual(calls, ["ran"])
            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"error-body")


if __name__ == "__main__":
    unittest.main()
