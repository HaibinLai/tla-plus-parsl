"""Runtime bridge for duplicate Zip members reaching a ready DataFuture."""

import tempfile
import unittest
import zipfile
from concurrent.futures import Future
from pathlib import Path

from parsl.app.futures import DataFuture
from parsl.data_provider.files import File
from parsl.data_provider.zip import _zip_stage_in


class ZipDuplicateReadinessRuntimeTest(unittest.TestCase):
    def test_duplicate_member_is_published_as_ready_with_latest_bytes_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "duplicate.zip"
            restored = root / "restored.bin"
            with zipfile.ZipFile(archive, "w") as archive_file:
                archive_file.writestr("result.bin", b"version-one")
                archive_file.writestr("result.bin", b"version-two")

            _zip_stage_in(
                str(archive),
                "result.bin",
                str(root),
                parent_fut=None,
                outputs=[File(str(restored))],
            )
            parent = Future()
            data_future = DataFuture(parent, File(str(restored)), tid=19)
            parent.set_result("stage-in-complete")

            self.assertTrue(data_future.done())
            self.assertEqual(data_future.result().filepath, str(restored))
            self.assertEqual(restored.read_bytes(), b"version-two")
            with zipfile.ZipFile(archive, "r") as archive_file:
                self.assertEqual(archive_file.namelist().count("result.bin"), 2)


if __name__ == "__main__":
    unittest.main()
