"""Runtime probes for WorkQueue submit-process failure bookkeeping."""

import tempfile
import threading
import unittest
from pathlib import Path

from parsl.data_provider.files import File
from parsl.executors.workqueue.errors import WorkQueueFailure
from parsl.executors.workqueue.executor import WorkQueueExecutor
from parsl.executors.errors import ExecutorError


class Process:
    def __init__(self, alive):
        self.alive = alive

    def is_alive(self):
        return self.alive


class Queue:
    def __init__(self):
        self.items = []

    def put_nowait(self, item):
        self.items.append(item)


class WorkQueueSubmitRuntimeTest(unittest.TestCase):
    def make_executor(self, directory, alive):
        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
        executor.function_data_dir = directory
        executor.executor_task_counter = -1
        executor.registered_files = set()
        executor._tasks = {}
        executor.tasks_lock = threading.Lock()
        executor.submit_process = Process(alive)
        executor.task_queue = Queue()
        executor.autolabel = False
        executor.autocategory = True
        executor.pack = False
        executor.source = False
        executor.extra_pkgs = []
        executor.shared_fs = False
        executor._register_file = lambda file_obj: str(file_obj)
        executor._std_output_to_wq = lambda kind, file_obj: str(file_obj)
        executor._serialize_function = lambda *args, **kwargs: None
        executor._construct_map_file = lambda *args, **kwargs: None
        return executor

    def test_dead_submit_process_leaves_orphaned_future(self):
        with tempfile.TemporaryDirectory() as directory:
            executor = self.make_executor(directory, alive=False)
            with self.assertRaises(ExecutorError):
                executor.submit(lambda: 1, {})

            self.assertIn("0", executor._tasks)
            self.assertFalse(executor.task_queue.items)

    def test_live_submit_process_queues_future(self):
        with tempfile.TemporaryDirectory() as directory:
            executor = self.make_executor(directory, alive=True)
            future = executor.submit(lambda: 1, {})

            self.assertIs(executor._tasks["0"], future)
            self.assertEqual(len(executor.task_queue.items), 1)

    def test_invalid_resource_key_is_rejected_before_task_mapping(self):
        with tempfile.TemporaryDirectory() as directory:
            executor = self.make_executor(directory, alive=False)
            with self.assertRaises(Exception):
                executor.submit(lambda: 1, {"unsupported": 1})
            self.assertEqual(executor._tasks, {})


if __name__ == "__main__":
    unittest.main()
