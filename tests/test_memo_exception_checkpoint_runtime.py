"""Probe failure memoization in one run versus checkpoint restart."""

import os
import pickle
import tempfile
import unittest
from concurrent.futures import Future

from parsl.dataflow.memoization import BasicMemoizer


def failed_task(app_future):
    return {
        "id": "failed-task",
        "memoize": True,
        "hashsum": "failure-key",
        "app_fu": app_future,
    }


class MemoExceptionCheckpointRuntimeTest(unittest.TestCase):
    def test_failure_is_in_memory_but_not_checkpointed(self):
        with tempfile.TemporaryDirectory() as run_dir:
            memoizer = BasicMemoizer(checkpoint_mode="task_exit")
            memoizer.start(run_dir=run_dir, config_run_dir=run_dir)
            failed = Future()
            failed.set_exception(RuntimeError("boom"))
            memoizer.update_memo_exception(failed_task(failed), RuntimeError("boom"))

            self.assertIn("failure-key", memoizer.memo_lookup_table)
            checkpoint_file = os.path.join(run_dir, "checkpoint", "tasks.pkl")
            self.assertTrue(os.path.exists(checkpoint_file))
            self.assertEqual(os.path.getsize(checkpoint_file), 0)

            restarted = BasicMemoizer(checkpoint_files=[os.path.join(run_dir, "checkpoint")])
            restarted.start(run_dir=run_dir, config_run_dir=run_dir)
            self.assertNotIn("failure-key", restarted.memo_lookup_table)

    def test_checkpoint_loader_cannot_restore_failure_from_normal_writer(self):
        with tempfile.TemporaryDirectory() as run_dir:
            checkpoint_dir = os.path.join(run_dir, "checkpoint")
            os.makedirs(checkpoint_dir)
            path = os.path.join(checkpoint_dir, "tasks.pkl")
            with open(path, "ab") as stream:
                pickle.dump({"hash": "failure-key", "exception": None, "result": "ok"}, stream)

            loaded = BasicMemoizer().load_checkpoints([checkpoint_dir])
            self.assertEqual(loaded["failure-key"].result(), "ok")


if __name__ == "__main__":
    unittest.main()
