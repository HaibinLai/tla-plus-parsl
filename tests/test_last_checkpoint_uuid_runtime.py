"""Probe get_last_checkpoint against current UUID-based DFK run directories."""

import os
import tempfile
import unittest

from parsl.utils import get_last_checkpoint


class LastCheckpointUUIDRuntimeTest(unittest.TestCase):
    def test_uuid_run_directory_is_filtered_out(self):
        with tempfile.TemporaryDirectory() as run_dir:
            checkpoint = os.path.join(run_dir, "7a4f2c8e-uuid-run", "checkpoint")
            os.makedirs(checkpoint)
            self.assertEqual(get_last_checkpoint(run_dir), [])

    def test_numeric_legacy_run_directory_is_found(self):
        with tempfile.TemporaryDirectory() as run_dir:
            checkpoint = os.path.join(run_dir, "12", "checkpoint")
            os.makedirs(checkpoint)
            self.assertEqual(get_last_checkpoint(run_dir), [os.path.abspath(checkpoint)])


if __name__ == "__main__":
    unittest.main()
