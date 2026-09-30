"""Runtime probe for non-positive LocalProvider launcher PIDs."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.jobs.states import JobState
from parsl.providers.local.local import LocalProvider


class LocalPidAdmissionRuntimeTest(unittest.TestCase):
    def test_zero_pid_is_published_and_can_look_alive_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = LocalProvider()
            provider.script_dir = directory
            with patch(
                "parsl.providers.local.local.execute_wait",
                return_value=(0, "PID:0\n", ""),
            ):
                job_id = provider.submit("true", tasks_per_node=1)

            script = next(Path(directory).glob("*.sh"))
            Path(str(script) + ".ec").write_text("-", encoding="utf-8")
            statuses = provider.status([job_id])

            self.assertEqual(job_id, "0")
            self.assertEqual(statuses[0].state, JobState.RUNNING)
            self.assertEqual(provider.resources[job_id]["remote_pid"], 0)


if __name__ == "__main__":
    unittest.main()
