"""Runtime probe for separate-task HTTP status validation."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.http import _http_stage_in


class ErrorResponse:
    status_code = 404

    def iter_content(self, chunk_size):
        yield b"not found"


class HTTPSeparateStatusRuntimeTest(unittest.TestCase):
    def test_non_2xx_body_is_published_by_separate_stage_in_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("https://example.invalid/missing.txt")
            file_obj.local_path = str(Path(directory) / "missing.txt")
            with patch("parsl.data_provider.http.requests.get", return_value=ErrorResponse()):
                self.assertIsNone(_http_stage_in(directory, outputs=[file_obj]))

            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"not found")


if __name__ == "__main__":
    unittest.main()
