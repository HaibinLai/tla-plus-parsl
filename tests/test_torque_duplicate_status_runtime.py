"""Runtime probe for duplicate Torque status records."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.torque.torque import TorqueProvider, translate_table


class TorqueDuplicateStatusRuntimeTest(unittest.TestCase):
    def test_duplicate_job_lines_raise_value_error_currently(self):
        provider = TorqueProvider.__new__(TorqueProvider)
        provider.resources = {
            "42.server": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "out-42",
                "job_stderr_path": "err-42",
            },
        }
        provider.execute_wait = lambda command: (0, "42.server a b c R\n42.server a b c R\n", "")
        provider._translate_table = translate_table

        with self.assertRaises(ValueError):
            provider._status()


if __name__ == "__main__":
    unittest.main()
