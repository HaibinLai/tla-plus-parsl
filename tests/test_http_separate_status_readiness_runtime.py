"""Runtime bridge for HTTP separate-task status and DataFuture readiness."""

import tempfile
import unittest
from concurrent.futures import Future
from pathlib import Path
from unittest.mock import patch

from parsl.app.futures import DataFuture
from parsl.data_provider.files import File
from parsl.data_provider.http import _http_stage_in


class ErrorResponse:
    status_code = 404

    def iter_content(self, chunk_size):
        yield b"not found"


class HTTPSeparateStatusReadinessRuntimeTest(unittest.TestCase):
    def test_non_2xx_stage_in_can_make_datafuture_look_ready_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File("https://example.invalid/missing.txt")
            file_obj.local_path = str(Path(directory) / "missing.txt")
            with patch("parsl.data_provider.http.requests.get", return_value=ErrorResponse()):
                self.assertIsNone(_http_stage_in(directory, outputs=[file_obj]))

            parent = Future()
            data_future = DataFuture(parent, file_obj, tid=7)
            parent.set_result(None)

            published = data_future.result(timeout=1)
            self.assertEqual(published, file_obj)
            self.assertEqual(Path(published.local_path).read_bytes(), b"not found")


if __name__ == "__main__":
    unittest.main()
