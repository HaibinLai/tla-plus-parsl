"""Runtime probe for failed HTTP replacement of an existing staged file."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.http import in_task_transfer_wrapper


class FailingReplacementResponse:
    status_code = 200

    def iter_content(self, chunk_size):
        yield b"new-partial"
        raise OSError("connection reset during replacement")


class HTTPExistingDestinationRuntimeTest(unittest.TestCase):
    def test_failed_transfer_truncates_existing_destination_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.bin"
            path.write_bytes(b"known-good-old-version")

            file_obj = File("https://example.invalid/input.bin")
            file_obj.local_path = str(path)
            wrapped = in_task_transfer_wrapper(lambda: "app", file_obj, directory)

            with patch("parsl.data_provider.http.requests.get", return_value=FailingReplacementResponse()):
                with self.assertRaises(OSError):
                    wrapped()

            # ``open(path, 'wb')`` truncates the old version before the first
            # response chunk.  A temporary destination plus atomic replace
            # would leave the old bytes available after this failure.
            self.assertEqual(path.read_bytes(), b"new-partial")


if __name__ == "__main__":
    unittest.main()
