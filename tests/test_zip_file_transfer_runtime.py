"""Runtime probes for the local ZipFileStaging byte-transfer path."""

import tempfile
import unittest
from pathlib import Path

from parsl.data_provider.file_noop import NoOpFileStaging
from parsl.data_provider.files import File
from parsl.data_provider.zip import _zip_stage_in, _zip_stage_out


class ZipFileTransferRuntimeTest(unittest.TestCase):
    def test_stage_out_and_stage_in_preserve_bytes(self):
        payload = b"parsl\x00stage-out\xff\n"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.bin"
            archive = root / "payload.zip"
            restored = root / "restored.bin"
            source.write_bytes(payload)

            _zip_stage_out(
                str(archive),
                "nested/result.bin",
                str(root),
                inputs=[File(str(source))],
            )

            self.assertFalse(source.exists())
            self.assertTrue(archive.exists())

            _zip_stage_in(
                str(archive),
                "nested/result.bin",
                str(root),
                parent_fut=None,
                outputs=[File(str(restored))],
            )

            self.assertEqual(restored.read_bytes(), payload)

    def test_bad_archive_fails_without_creating_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "bad.zip"
            restored = root / "restored.bin"
            archive.write_bytes(b"not a zip archive")

            with self.assertRaises(Exception):
                _zip_stage_in(
                    str(archive),
                    "nested/result.bin",
                    str(root),
                    parent_fut=None,
                    outputs=[File(str(restored))],
                )

            self.assertFalse(restored.exists())

    def test_noop_provider_only_accepts_local_file_scheme(self):
        provider = NoOpFileStaging()
        self.assertTrue(provider.can_stage_in(File("/tmp/input")))
        self.assertTrue(provider.can_stage_out(File("file:///tmp/output")))
        self.assertFalse(provider.can_stage_in(File("zip:/tmp/a.zip/x")))


if __name__ == "__main__":
    unittest.main()
