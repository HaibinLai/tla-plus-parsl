"""Runtime probe for zero tasks_per_node in LocalProvider."""

import tempfile
import time
import unittest

from parsl.jobs.states import JobState
from parsl.providers.local.local import LocalProvider


class LocalTasksPerNodeRuntimeTest(unittest.TestCase):
    def test_zero_tasks_per_node_creates_failed_job_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = LocalProvider()
            provider.script_dir = directory
            job_id = provider.submit("true", tasks_per_node=0)

            status = None
            for _ in range(100):
                status = provider.status([job_id])[0]
                if status.terminal:
                    break
                time.sleep(0.02)

            self.assertIsNotNone(status)
            self.assertEqual(status.state, JobState.FAILED)


if __name__ == "__main__":
    unittest.main()
