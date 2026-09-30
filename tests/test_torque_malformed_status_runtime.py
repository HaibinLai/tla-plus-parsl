"""Runtime probe for malformed Torque qstat status records."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.torque.torque import TorqueProvider, translate_table


class TorqueMalformedStatusRuntimeTest(unittest.TestCase):
    def test_truncated_qstat_line_raises_index_error_currently(self):
        provider = TorqueProvider.__new__(TorqueProvider)
        provider.resources = {
            "42.server": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "out-42",
                "job_stderr_path": "err-42",
            },
        }
        provider.execute_wait = lambda command: (0, "42.server R\n", "")
        provider._translate_table = translate_table

        with self.assertRaises(IndexError):
            provider._status()


if __name__ == "__main__":
    unittest.main()
