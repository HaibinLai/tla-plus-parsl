"""Runtime probe for task-dictionary mutation during executor failure fan-out."""

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


class BadStateTaskMutationRuntimeTest(unittest.TestCase):
    def test_callback_removing_task_breaks_current_failure_fanout(self):
        executor = ProbeExecutor()
        future = Future()
        executor.tasks["task-0"] = future
        future.add_done_callback(lambda _: executor.tasks.pop("task-0"))

        with self.assertRaisesRegex(RuntimeError, "dictionary changed size"):
            executor.set_bad_state_and_fail_all(RuntimeError("worker failure"))


if __name__ == "__main__":
    unittest.main()
