"""Runtime probes for DataFlowKernel cleanup ordering and repeat protection."""

import unittest

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.states import States


class Recorder:
    def __init__(self, label, events):
        self.label = label
        self.events = events

    def close(self):
        self.events.append(self.label)

    def send_end_message(self):
        self.events.append(self.label)


class ExecutorRecorder:
    def __init__(self, events):
        self.label = "executors"
        self.events = events

    def shutdown(self):
        self.events.append(self.label)


class UsageRecorder:
    def __init__(self, events):
        self.events = events

    def send_end_message(self):
        self.events.append("usage")

    def close(self):
        pass


class DataFlowCleanupRuntimeTest(unittest.TestCase):
    def kernel(self):
        events = []
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.cleanup_called = False
        kernel.memoizer = Recorder("memoizer", events)
        kernel.usage_tracker = UsageRecorder(events)
        kernel.job_status_poller = Recorder("poller", events)
        kernel.executors = {"e": ExecutorRecorder(events)}
        kernel.task_state_counts = {States.failed: 0, States.exec_done: 0}
        kernel.run_id = "run"
        kernel.run_dir = "/tmp/run"
        kernel.monitoring_radio = None
        kernel.monitoring = Recorder("monitoring", events)
        kernel._task_launch_pool = ExecutorRecorder(events)
        kernel._task_launch_pool.label = "task-launch-pool"
        kernel.atexit_cleanup = lambda: None
        kernel._logging_unregister_callback = None
        kernel.log_task_states = lambda: None
        return kernel, events

    def test_cleanup_closes_components_in_source_order(self):
        kernel, events = self.kernel()

        kernel.cleanup()

        self.assertEqual(events, ["memoizer", "usage", "poller", "executors", "monitoring", "task-launch-pool"])
        self.assertTrue(kernel.cleanup_called)

    def test_second_cleanup_is_rejected(self):
        kernel, events = self.kernel()
        kernel.cleanup()

        with self.assertRaises(Exception):
            kernel.cleanup()
        self.assertEqual(events, ["memoizer", "usage", "poller", "executors", "monitoring", "task-launch-pool"])


if __name__ == "__main__":
    unittest.main()
