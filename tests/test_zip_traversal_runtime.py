"""Runtime probe for zip member path traversal during stage-in."""

import tempfile
import unittest
import zipfile
from pathlib import Path

from parsl.data_provider.files import File
from parsl.data_provider.zip import _zip_stage_in


class ZipTraversalRuntimeTest(unittest.TestCase):
    def test_parent_member_is_written_outside_working_directory_currently(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            work = root / "worker"
            work.mkdir()
            archive = root / "payload.zip"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("../escaped.txt", b"outside")

            output = File(str(work / "../escaped.txt"))
            output.local_path = str(work / "../escaped.txt")
            _zip_stage_in(
                str(archive),
                "../escaped.txt",
                str(work),
                parent_fut=None,
                outputs=[output],
            )

            escaped = root / "escaped.txt"
            self.assertEqual(escaped.read_bytes(), b"outside")
            self.assertFalse((work / "escaped.txt").exists())


if __name__ == "__main__":
    unittest.main()
