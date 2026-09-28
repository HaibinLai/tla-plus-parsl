"""Runtime probe for shell quoting in RSyncStaging commands."""

import shlex
import unittest
from unittest.mock import patch

from parsl.data_provider.files import File
from parsl.data_provider.rsync import in_task_stage_in_wrapper


class RSyncQuotingRuntimeTest(unittest.TestCase):
    def test_paths_with_spaces_are_split_by_current_command_builder(self):
        file_obj = File("/remote/input file.txt")
        file_obj.local_path = "/worker/input file.txt"
        commands = []
        wrapped = in_task_stage_in_wrapper(
            lambda: "ok", file_obj, "", "submit-host"
        )

        with patch(
            "parsl.data_provider.rsync.os.system",
            side_effect=lambda command: commands.append(command) or 0,
        ):
            self.assertEqual(wrapped(), "ok")

        self.assertEqual(len(commands), 1)
        # The unquoted path becomes separate shell words, so it cannot be a
        # reliable single rsync source/destination argument.
        self.assertEqual(
            shlex.split(commands[0]),
            ["rsync", "submit-host:/remote/input", "file.txt", "/worker/input", "file.txt"],
        )


if __name__ == "__main__":
    unittest.main()
