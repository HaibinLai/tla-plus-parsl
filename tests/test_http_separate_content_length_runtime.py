"""Runtime probe for separate-task HTTP content-length validation."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.http import _http_stage_in


class ShortResponse:
    headers = {"Content-Length": "5"}

    def iter_content(self, chunk_size):
        yield b"abc"


class HTTPSeparateContentLengthRuntimeTest(unittest.TestCase):
    def test_short_response_is_published_by_separate_stage_in_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("https://example.invalid/input")
            file_obj.local_path = str(Path(directory) / "input.bin")
            with patch("parsl.data_provider.http.requests.get", return_value=ShortResponse()):
                self.assertIsNone(_http_stage_in(directory, outputs=[file_obj]))

            self.assertEqual(Path(file_obj.local_path).read_bytes(), b"abc")


if __name__ == "__main__":
    unittest.main()
