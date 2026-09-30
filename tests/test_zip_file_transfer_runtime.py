"""Runtime probes for the local ZipFileStaging byte-transfer path."""

import tempfile
import unittest
from unittest import mock
import zipfile
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

    def test_output_write_failure_leaves_partial_file_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "payload.zip"
            restored = root / "restored.bin"
            payload = b"a complete archive member"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("nested/result.bin", payload)

            real_open = open

            class PartialWriter:
                def __init__(self, path):
                    self.handle = real_open(path, "wb")

                def __enter__(self):
                    return self

                def __exit__(self, exc_type, exc, tb):
                    self.handle.close()
                    return False

                def write(self, data):
                    prefix = data[: max(1, len(data) // 2)]
                    self.handle.write(prefix)
                    self.handle.flush()
                    raise OSError("disk full")

            def failing_open(path, mode="r", *args, **kwargs):
                if str(path) == str(restored) and mode == "wb":
                    return PartialWriter(path)
                return real_open(path, mode, *args, **kwargs)

            with mock.patch("builtins.open", side_effect=failing_open):
                with self.assertRaises(OSError):
                    _zip_stage_in(
                        str(archive),
                        "nested/result.bin",
                        str(root),
                        parent_fut=None,
                        outputs=[File(str(restored))],
                    )

            self.assertTrue(restored.exists())
            self.assertGreater(restored.stat().st_size, 0)

    def test_noop_provider_only_accepts_local_file_scheme(self):
        provider = NoOpFileStaging()
        self.assertTrue(provider.can_stage_in(File("/tmp/input")))
        self.assertTrue(provider.can_stage_out(File("file:///tmp/output")))
        self.assertFalse(provider.can_stage_in(File("zip:/tmp/a.zip/x")))

    def test_stage_out_retry_can_leave_a_duplicate_archive_entry_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.bin"
            archive = root / "payload.zip"
            source.write_bytes(b"version-one")

            # The staging module uses the process-wide os module; save the
            # original function before patching it.
            import os
            real_remove = os.remove
            calls = 0

            def fail_once(path):
                nonlocal calls
                calls += 1
                if calls == 1:
                    raise OSError("source cleanup failed")
                return real_remove(path)

            with mock.patch("parsl.data_provider.zip.os.remove", side_effect=fail_once):
                with self.assertRaises(OSError):
                    _zip_stage_out(
                        str(archive),
                        "nested/result.bin",
                        str(root),
                        inputs=[File(str(source))],
                    )

            self.assertTrue(source.exists())
            source.write_bytes(b"version-two")
            _zip_stage_out(
                str(archive),
                "nested/result.bin",
                str(root),
                inputs=[File(str(source))],
            )

            with zipfile.ZipFile(archive, "r") as z:
                self.assertEqual(z.namelist().count("nested/result.bin"), 2)
                # Python's ZipFile lookup returns the latest duplicate, but
                # the archive still contains two entries and emits a warning.
                self.assertEqual(z.read("nested/result.bin"), b"version-two")

    def test_stage_in_duplicate_member_silently_selects_last_entry_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "duplicate.zip"
            restored = root / "restored.bin"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("nested/result.bin", b"version-one")
                z.writestr("nested/result.bin", b"version-two")

            _zip_stage_in(
                str(archive),
                "nested/result.bin",
                str(root),
                parent_fut=None,
                outputs=[File(str(restored))],
            )

            self.assertEqual(restored.read_bytes(), b"version-two")
            with zipfile.ZipFile(archive, "r") as z:
                self.assertEqual(z.namelist().count("nested/result.bin"), 2)


if __name__ == "__main__":
    unittest.main()
