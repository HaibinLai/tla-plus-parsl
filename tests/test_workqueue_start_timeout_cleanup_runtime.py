"""Runtime probe for WorkQueue startup timeout cleanup."""

import queue
import tempfile
import unittest
from unittest.mock import patch

from parsl.executors.status_handling import BlockProviderExecutor
from parsl.executors.workqueue import executor as workqueue_executor
from parsl.executors.workqueue.executor import WorkQueueExecutor


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
        self.stopped = False

    def start(self):
        self.started = True

    def join(self, *args, **kwargs):
        self.stopped = True


class EmptyMailbox:
    def get(self, timeout=None):
        raise queue.Empty


class WorkQueueStartTimeoutRuntimeTest(unittest.TestCase):
    def make_executor(self, root):
        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
        executor._run_dir = root
        executor.label = "wq"
        executor.function_dir = None
        executor.task_queue = object()
        executor.collector_queue = object()
        executor.launch_cmd = "launch"
        executor.autolabel = False
        executor.autolabel_window = 1
        executor.autocategory = True
        executor.max_retries = 1
        executor.should_stop = object()
        executor.port = 0
        executor.wq_log_dir = root
        executor.project_password_file = None
        executor.project_name = None
        executor.coprocess = False
        executor.full_debug = False
        executor.shared_fs = False
        executor.initialize_scaling = lambda: None
        return executor

    def test_port_timeout_leaves_started_components_currently(self):
        with tempfile.TemporaryDirectory() as root:
            executor = self.make_executor(root)
            with patch.object(BlockProviderExecutor, "start"), \
                 patch.object(workqueue_executor, "SpawnProcess", FakeProcess), \
                 patch.object(workqueue_executor.threading, "Thread", FakeThread), \
                 patch.object(workqueue_executor.SpawnContext, "Queue", return_value=EmptyMailbox()):
                with self.assertRaises(queue.Empty):
                    executor.start()

            self.assertTrue(executor.submit_process.started)
            self.assertTrue(executor.collector_thread.started)
            self.assertFalse(executor.submit_process.stopped)
            self.assertFalse(executor.collector_thread.stopped)

    def test_candidate_cleanup_stops_components_after_port_timeout(self):
        process = FakeProcess()
        thread = FakeThread()
        process.start()
        thread.start()
        try:
            raise queue.Empty
        except queue.Empty:
            process.terminate()
            thread.join()

        self.assertTrue(process.stopped)
        self.assertTrue(thread.stopped)


if __name__ == "__main__":
    unittest.main()
