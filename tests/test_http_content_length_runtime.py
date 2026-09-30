"""Runtime probe for HTTP transfers shorter than Content-Length."""

import tempfile
import types
import unittest
from unittest.mock import patch

from parsl.data_provider.http import in_task_transfer_wrapper


class ShortResponse:
    headers = {"Content-Length": "5"}

    def iter_content(self, chunk_size):
        self.chunk_size = chunk_size
        yield b"abc"


class HTTPContentLengthRuntimeTest(unittest.TestCase):
    def test_short_success_response_is_published_and_app_runs_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            path = f"{directory}/input.bin"
            file = types.SimpleNamespace(url="https://example.invalid/input", local_path=path)
            app = in_task_transfer_wrapper(lambda: "ran", file, directory)

            with patch("requests.get", return_value=ShortResponse()):
                self.assertEqual(app(), "ran")

            with open(path, "rb") as stream:
                self.assertEqual(stream.read(), b"abc")


if __name__ == "__main__":
    unittest.main()
