"""Runtime probe for stale bytes published by the rsync stage-out wrapper."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.rsync import in_task_stage_out_wrapper


class RsyncStageOutVersionRuntimeTest(unittest.TestCase):
    def test_successful_copy_can_publish_old_bytes_after_source_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "result.txt"
            source.write_bytes(b"version-0")
            file = File("file:///remote/result.txt")
            file.local_path = str(source)

            published = []

            def copy_then_source_changes(command):
                # Simulate rsync reading the source before a concurrent writer
                # replaces it. The wrapper has no version/checksum check.
                published.append(source.read_bytes())
                source.write_bytes(b"version-1")
                return 0

            wrapped = in_task_stage_out_wrapper(
                lambda: "application-result", file, None, "remote-host"
            )

            with patch("parsl.data_provider.rsync.os.system", side_effect=copy_then_source_changes):
                self.assertEqual(wrapped(), "application-result")

            self.assertEqual(published, [b"version-0"])
            self.assertEqual(source.read_bytes(), b"version-1")


if __name__ == "__main__":
    unittest.main()
