"""Runtime bridge for the callable-snapshot and file-publication pipeline."""

import tempfile
import unittest
import zipfile
from pathlib import Path

from parsl.data_provider.files import File
from parsl.data_provider.zip import _zip_stage_in
from parsl.serialize.facade import pack_apply_message, unpack_apply_message


def make_adder(box):
    def add(value):
        return value + box["offset"]

    return add


class ContentFilePipelineRuntimeTest(unittest.TestCase):
    def test_payload_snapshot_and_verified_file_gate_are_composed(self):
        box = {"offset": 3}
        payload = pack_apply_message(make_adder(box), (4,), {})
        box["offset"] = 99

        content = b"file-input-v0\x00\xff"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "input.zip"
            restored = root / "restored.bin"
            with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as zf:
                zf.writestr("chunks/input.bin", content)

            # The staged file is not readable until the transfer action has
            # published it; then both the callable snapshot and file bytes are
            # consumed by one logical worker step.
            self.assertFalse(restored.exists())
            _zip_stage_in(
                str(archive), "chunks/input.bin", str(root),
                parent_fut=None, outputs=[File(str(restored))],
            )
            self.assertEqual(restored.read_bytes(), content)

            decoded_func, args, kwargs = unpack_apply_message(payload)
            self.assertEqual(decoded_func(*args, **kwargs), 7)
            self.assertEqual(restored.read_bytes(), content)


if __name__ == "__main__":
    unittest.main()
