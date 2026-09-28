"""Runtime probe for HTTP in-task staging status handling."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.http import in_task_transfer_wrapper


class FakeResponse:
    status_code = 404

    def iter_content(self, chunk_size):
        yield b"error page"


class HTTPStagingRuntimeTest(unittest.TestCase):
    def test_non_success_response_currently_reaches_user_function(self):
        calls = []
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("https://example.invalid/input.txt")
            file_obj.local_path = str(Path(directory) / "input.txt")
            wrapped = in_task_transfer_wrapper(
                lambda: calls.append("app") or "result", file_obj, directory
            )

            with patch("requests.get", return_value=FakeResponse()):
                self.assertEqual(wrapped(), "result")

            self.assertEqual(calls, ["app"])
            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"error page")


if __name__ == "__main__":
    unittest.main()
