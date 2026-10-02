"""Runtime bridge for PBS Pro malformed status and Future monitoring."""

import unittest
from concurrent.futures import Future

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.pbspro.pbspro import PBSProProvider


class PBSProMalformedFutureMonitoringRuntimeTest(unittest.TestCase):
    def test_malformed_status_strands_task_future_currently(self):
        provider = PBSProProvider.__new__(PBSProProvider)
        provider.resources = {
            "42.server": {
                "status": JobStatus(JobState.RUNNING),
                "job_stdout_path": "42.out",
                "job_stderr_path": "42.err",
            },
        }
        provider.execute_wait = lambda command: (0, "{not-json", "")
        task_future = Future()
        monitoring_events = []

        with self.assertRaises(ValueError):
            provider._status()
            task_future.set_exception(RuntimeError("status decode failed"))
            monitoring_events.append("failed")

        self.assertFalse(task_future.done())
        self.assertEqual(monitoring_events, [])
        self.assertEqual(provider.resources["42.server"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
