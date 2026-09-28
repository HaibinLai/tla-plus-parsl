"""Probe duplicate checkpoint hashes and UUID-directory ordering."""

import os
import pickle
import tempfile
import unittest

from parsl.dataflow.memoization import BasicMemoizer
from parsl.utils import get_all_checkpoints


class MemoCheckpointOrderRuntimeTest(unittest.TestCase):
    def test_lexical_uuid_order_can_restore_an_older_duplicate(self):
        with tempfile.TemporaryDirectory() as run_dir:
            # Create the chronologically newer run first in the lexical order,
            # then create the older run second. UUID names have no chronology.
            old = os.path.join(run_dir, "b0000000-old", "checkpoint")
            new = os.path.join(run_dir, "a0000000-new", "checkpoint")
            os.makedirs(old)
            os.makedirs(new)
            with open(os.path.join(old, "tasks.pkl"), "wb") as stream:
                pickle.dump({"hash": "same", "exception": None, "result": "old"}, stream)
            with open(os.path.join(new, "tasks.pkl"), "wb") as stream:
                pickle.dump({"hash": "same", "exception": None, "result": "new"}, stream)

            checkpoints = get_all_checkpoints(run_dir)
            self.assertEqual(checkpoints[0], os.path.abspath(new))
            memoizer = BasicMemoizer(checkpoint_files=checkpoints)
            memoizer.start(run_dir=run_dir, config_run_dir=run_dir)

            # The second lexical load overwrites the first, so the older value wins.
            self.assertEqual(memoizer.memo_lookup_table["same"].result(), "old")


if __name__ == "__main__":
    unittest.main()
