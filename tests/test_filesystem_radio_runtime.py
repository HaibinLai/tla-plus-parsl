"""Runtime probes for filesystem monitoring-radio atomic publication."""

import pickle
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.monitoring.radios.filesystem import FilesystemRadioSender


class FilesystemRadioRuntimeTest(unittest.TestCase):
    def test_send_publishes_complete_pickle_only_in_new(self):
        with tempfile.TemporaryDirectory() as directory:
            sender = FilesystemRadioSender(run_dir=directory)
            sender.send(("task", {"value": 7}))

            tmp_files = list((Path(directory) / "monitor-fs-radio" / "tmp").iterdir())
            new_files = list((Path(directory) / "monitor-fs-radio" / "new").iterdir())
            self.assertEqual(tmp_files, [])
            self.assertEqual(len(new_files), 1)
            with new_files[0].open("rb") as handle:
                self.assertEqual(pickle.load(handle), ("task", {"value": 7}))

    def test_write_failure_never_exposes_partial_file_in_new(self):
        with tempfile.TemporaryDirectory() as directory:
            sender = FilesystemRadioSender(run_dir=directory)
            real_dump = pickle.dump

            def fail_dump(value, handle, *args, **kwargs):
                handle.write(b"partial-pickle")
                raise OSError("disk full")

            with patch("parsl.monitoring.radios.filesystem.pickle.dump", side_effect=fail_dump):
                with self.assertRaises(OSError):
                    sender.send(("task", {"value": 8}))

            tmp_dir = Path(directory) / "monitor-fs-radio" / "tmp"
            new_dir = Path(directory) / "monitor-fs-radio" / "new"
            self.assertEqual(len(list(tmp_dir.iterdir())), 1)
            self.assertEqual(list(new_dir.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
