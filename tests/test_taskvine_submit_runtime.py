"""Runtime probes for TaskVine submit failure bookkeeping."""

import tempfile
import threading
import unittest
from types import SimpleNamespace

from parsl.executors.errors import ExecutorError
from parsl.executors.taskvine.executor import TaskVineExecutor


class FakeProcess:
    def __init__(self, alive):
        self.alive = alive

    def is_alive(self):
        return self.alive


class FakeQueue:
    def __init__(self):
        self.items = []

    def put_nowait(self, item):
        self.items.append(item)


class TaskVineSubmitRuntimeTest(unittest.TestCase):
    def make_executor(self, tempdir, alive, serialize_error=False):
        executor = TaskVineExecutor.__new__(TaskVineExecutor)
        executor._function_data_dir = tempdir
        executor._executor_task_counter = 0
        executor._tasks = {}
        executor._tasks_lock = threading.Lock()
        executor._outstanding_tasks_lock = threading.Lock()
        executor._outstanding_tasks = 0
        executor._submit_process = FakeProcess(alive)
        executor._ready_task_queue = FakeQueue()
        executor.function_exec_mode = "regular"
        executor.extra_pkgs = []
        executor.manager_config = SimpleNamespace(
            app_pack=False,
            autocategory=True,
            shared_fs=False,
        )
        executor._register_file = lambda file_obj: str(file_obj)
        executor._std_output_to_vine = lambda kind, file_obj: str(file_obj)
        executor._construct_map_file = lambda *args, **kwargs: None
        if serialize_error:
            def fail(*args, **kwargs):
                raise TypeError("cannot serialize closure")
            executor._serialize_object_to_file = fail
        else:
            executor._serialize_object_to_file = lambda *args, **kwargs: None
        return executor

    def test_dead_submit_process_leaves_orphaned_future(self):
        with tempfile.TemporaryDirectory() as root:
            tempdir = tempfile.TemporaryDirectory(dir=root)
            executor = self.make_executor(tempdir, alive=False)
            with self.assertRaises(ExecutorError):
                executor.submit(lambda: 1, {})
            self.assertIn("0", executor._tasks)
            self.assertEqual(executor._outstanding_tasks, 0)
            tempdir.cleanup()

    def test_serialization_failure_leaves_orphaned_future(self):
        with tempfile.TemporaryDirectory() as root:
            tempdir = tempfile.TemporaryDirectory(dir=root)
            executor = self.make_executor(tempdir, alive=True, serialize_error=True)
            with self.assertRaises(TypeError):
                executor.submit(lambda: 1, {})
            self.assertIn("0", executor._tasks)
            self.assertEqual(executor._outstanding_tasks, 0)
            tempdir.cleanup()


if __name__ == "__main__":
    unittest.main()
