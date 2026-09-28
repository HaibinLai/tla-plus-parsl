"""Runtime probes for RSyncStaging in-task wrapper failure ordering."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.rsync import (
    in_task_stage_in_wrapper,
    in_task_stage_out_wrapper,
)


class RSyncStagingRuntimeTest(unittest.TestCase):
    def test_stage_in_failure_prevents_user_function(self):
        calls = []
        file_obj = File("/remote/input.txt")
        file_obj.local_path = "/worker/input.txt"
        wrapped = in_task_stage_in_wrapper(
            lambda: calls.append("app"), file_obj, "", "submit-host"
        )

        with patch("parsl.data_provider.rsync.os.system", return_value=1):
            with self.assertRaises(RuntimeError):
                wrapped()

        self.assertEqual(calls, [])

    def test_stage_out_failure_occurs_after_user_function(self):
        calls = []
        with tempfile.TemporaryDirectory() as directory:
            file_obj = File(str(Path(directory) / "output.txt"))
            file_obj.local_path = str(Path(directory) / "worker-output.txt")
            wrapped = in_task_stage_out_wrapper(
                lambda: calls.append("app") or "result",
                file_obj,
                directory,
                "submit-host",
            )

            with patch("parsl.data_provider.rsync.os.system", return_value=1):
                with self.assertRaises(RuntimeError):
                    wrapped()

        self.assertEqual(calls, ["app"])


if __name__ == "__main__":
    unittest.main()
