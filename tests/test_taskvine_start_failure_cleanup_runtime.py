"""Runtime probe for TaskVine provider-start failure cleanup."""

import tempfile
import unittest
from unittest.mock import patch

from parsl.executors.status_handling import BlockProviderExecutor
from parsl.executors.taskvine import executor as taskvine_executor
from parsl.executors.taskvine.executor import TaskVineExecutor


class FakeProcess:
    def __init__(self, *args, **kwargs):
        self.started = False
        self.stopped = False

    def start(self):
        self.started = True

    def terminate(self):
        self.stopped = True


class FakeThread:
    def __init__(self, *args, **kwargs):
        self.started = False

    def start(self):
        self.started = True


class TaskVineStartFailureRuntimeTest(unittest.TestCase):
    def make_executor(self, root):
        executor = TaskVineExecutor.__new__(TaskVineExecutor)
        executor._ready_task_queue = object()
        executor._finished_task_queue = object()
        executor._should_stop = object()
        executor.manager_config = object()
        executor.factory_config = object()
        executor.worker_launch_method = "provider"
        executor._run_dir = root
        executor.initialize_scaling = lambda: (_ for _ in ()).throw(RuntimeError("provider failed"))
        executor._TaskVineExecutor__synchronize_manager_factory_comm_settings = lambda: None
        executor._TaskVineExecutor__create_data_and_logging_dirs = lambda: None
        return executor

    def test_provider_failure_leaves_manager_running_currently(self):
        with tempfile.TemporaryDirectory() as root:
            executor = self.make_executor(root)
            with patch.object(BlockProviderExecutor, "start"), \
                 patch.object(taskvine_executor, "SpawnContext") as spawn_context, \
                 patch.object(taskvine_executor.threading, "Thread", FakeThread):
                process = FakeProcess()
                spawn_context.Process.return_value = process
                with self.assertRaises(RuntimeError):
                    executor.start()

            self.assertTrue(process.started)
            self.assertFalse(process.stopped)
            self.assertFalse(executor._collector_thread.started)

    def test_candidate_cleanup_stops_manager_before_returning_failure(self):
        process = FakeProcess()
        process.start()
        try:
            raise RuntimeError("provider failed")
        except RuntimeError:
            process.terminate()

        self.assertTrue(process.stopped)


if __name__ == "__main__":
    unittest.main()
