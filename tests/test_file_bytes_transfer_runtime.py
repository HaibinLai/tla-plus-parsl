"""Runtime bridge for the bounded file-byte/checksum abstraction."""

import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from parsl.data_provider.files import File
from parsl.data_provider.zip import _zip_stage_in, _zip_stage_out


class FileBytesTransferRuntimeTest(unittest.TestCase):
    def test_chunk_content_and_checksums_survive_archive_transfer(self):
        payload = (b"chunk-0\x00\xff" * 11) + (b"chunk-1\n" * 13)
        chunk_size = 17
        chunks = [payload[i:i + chunk_size] for i in range(0, len(payload), chunk_size)]
        expected = [hashlib.sha256(chunk).hexdigest() for chunk in chunks]

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.bin"
            archive = root / "transfer.zip"
            restored = root / "restored.bin"
            source.write_bytes(payload)

            _zip_stage_out(
                str(archive), "data/source.bin", str(root), inputs=[File(str(source))]
            )
            _zip_stage_in(
                str(archive), "data/source.bin", str(root),
                parent_fut=None, outputs=[File(str(restored))],
            )

            restored_bytes = restored.read_bytes()
            actual = [
                hashlib.sha256(restored_bytes[i:i + chunk_size]).hexdigest()
                for i in range(0, len(restored_bytes), chunk_size)
            ]
            self.assertEqual(restored_bytes, payload)
            self.assertEqual(actual, expected)

    def test_corrupt_archive_payload_is_rejected_before_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "corrupt.zip"
            restored = root / "restored.bin"

            with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as zf:
                zf.writestr("data.bin", b"known-good-payload")

            archive_bytes = bytearray(archive.read_bytes())
            payload_offset = archive_bytes.find(b"known-good-payload")
            self.assertGreaterEqual(payload_offset, 0)
            archive_bytes[payload_offset] ^= 0x01
            archive.write_bytes(archive_bytes)

            with self.assertRaises(zipfile.BadZipFile):
                _zip_stage_in(
                    str(archive), "data.bin", str(root),
                    parent_fut=None, outputs=[File(str(restored))],
                )

            self.assertFalse(restored.exists())


if __name__ == "__main__":
    unittest.main()
