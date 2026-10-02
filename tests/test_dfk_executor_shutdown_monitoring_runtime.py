"""Runtime probe for DFK cleanup when an executor shutdown fails."""

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


class FailingExecutor:
    label = "executor"

    def __init__(self, events):
        self.events = events

    def shutdown(self):
        self.events.append("executor-shutdown")
        raise RuntimeError("executor shutdown failed")


class LaunchPool:
    def shutdown(self):
        pass


class DfkExecutorShutdownMonitoringRuntimeTest(unittest.TestCase):
    def test_current_shutdown_failure_skips_workflow_monitoring_finalization(self):
        events = []
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.cleanup_called = False
        kernel.memoizer = Recorder("memoizer", events)
        kernel.usage_tracker = Recorder("usage", events)
        kernel.job_status_poller = Recorder("poller", events)
        kernel.executors = {"e": FailingExecutor(events)}
        kernel.task_state_counts = {States.failed: 0, States.exec_done: 0}
        kernel.run_id = "run"
        kernel.run_dir = "/tmp/run"
        kernel.monitoring_radio = Recorder("workflow-info", events)
        kernel.monitoring = Recorder("monitoring", events)
        kernel._task_launch_pool = LaunchPool()
        kernel.atexit_cleanup = lambda: None
        kernel._logging_unregister_callback = None
        kernel.log_task_states = lambda: None

        with self.assertRaises(RuntimeError):
            kernel.cleanup()

        self.assertIn("executor-shutdown", events)
        self.assertNotIn("workflow-info", events)
        self.assertNotIn("monitoring", events)

    def test_candidate_fixed_path_continues_after_shutdown_failure(self):
        events = []
        try:
            FailingExecutor(events).shutdown()
        except RuntimeError:
            pass
        # Candidate cleanup behavior: isolate the executor error, then publish
        # the terminal workflow event and close monitoring.
        events.extend(["workflow-info", "monitoring"])
        self.assertEqual(events, ["executor-shutdown", "workflow-info", "monitoring"])


if __name__ == "__main__":
    unittest.main()
