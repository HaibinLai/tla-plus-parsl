"""Runtime bridge for bad-state fan-out and monitoring terminality."""

import unittest
from concurrent.futures import Future

from parsl.executors.status_handling import BlockProviderExecutor


class ProbeExecutor(BlockProviderExecutor):
    def __init__(self):
        super().__init__(provider=None, block_error_handler=False)

    def outstanding(self):
        return 0

    @property
    def workers_per_node(self):
        return 1

    def _get_launch_command(self, block_id):
        return "true"

    def submit(self, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self, *args, **kwargs):
        return None


class BadStateMonitoringRuntimeTest(unittest.TestCase):
    def test_live_dictionary_abort_leaves_future_and_monitor_pending_currently(self):
        executor = ProbeExecutor()
        first = Future()
        second = Future()
        monitoring = []
        executor.tasks["task-0"] = first
        executor.tasks["task-1"] = second
        first.add_done_callback(lambda _: executor.tasks.pop("task-0"))
        first.add_done_callback(lambda _: monitoring.append("task-0"))
        second.add_done_callback(lambda _: monitoring.append("task-1"))

        with self.assertRaisesRegex(RuntimeError, "dictionary changed size"):
            executor.set_bad_state_and_fail_all(RuntimeError("provider lost"))

        self.assertTrue(first.done())
        self.assertFalse(second.done())
        self.assertEqual(monitoring, ["task-0"])


if __name__ == "__main__":
    unittest.main()
