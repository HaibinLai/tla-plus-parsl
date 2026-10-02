"""Runtime bridge for Condor empty submit and Future/monitoring terminality."""

import unittest
from concurrent.futures import Future

from parsl.providers.condor.condor import CondorProvider


class CondorEmptySubmitFutureMonitoringRuntimeTest(unittest.TestCase):
    def test_empty_submit_strands_logical_future_currently(self):
        provider = CondorProvider.__new__(CondorProvider)
        provider.script_dir = "/tmp"
        provider.nodes_per_block = 1
        provider.scheduler_options = ""
        provider.worker_init = ""
        provider.environment = {}
        provider.project = ""
        provider.requirements = ""
        provider.transfer_input_files = []
        provider.mem_per_slot = None
        provider.cores_per_slot = None
        provider.resources = {}
        provider._write_submit_script = lambda *args, **kwargs: None
        provider.execute_wait = lambda command: (0, "", "")
        provider.launcher = lambda *args: "worker"

        task_future = Future()
        monitoring_events = []
        with self.assertRaises(IndexError):
            provider.submit("worker", tasks_per_node=1)
            task_future.set_exception(RuntimeError("submit failed"))
            monitoring_events.append("failed")

        self.assertFalse(task_future.done())
        self.assertEqual(monitoring_events, [])
        self.assertEqual(provider.resources, {})


if __name__ == "__main__":
    unittest.main()
