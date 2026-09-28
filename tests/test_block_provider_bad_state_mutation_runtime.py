"""Probe mutation of the task dictionary during bad-state failure callbacks."""

import threading
import unittest
from concurrent.futures import Future

from parsl.executors.status_handling import BlockProviderExecutor


class DummyBlockExecutor(BlockProviderExecutor):
    def __init__(self):
        pass

    def outstanding(self):
        return 0

    def _get_launch_command(self, block_id):
        return "launch"

    def submit(self, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self):
        pass

    @property
    def workers_per_node(self):
        return 1


class BlockProviderBadStateMutationRuntimeTest(unittest.TestCase):
    def test_callback_mutation_can_abort_live_dictionary_iteration(self):
        executor = DummyBlockExecutor()
        executor._executor_bad_state = threading.Event()
        executor._executor_exception = None
        first = Future()
        second = Future()
        executor._tasks = {"first": first, "second": second}

        def mutate_tasks(_future):
            executor._tasks["callback-task"] = Future()

        first.add_done_callback(mutate_tasks)

        with self.assertRaises(RuntimeError):
            executor.set_bad_state_and_fail_all(RuntimeError("provider lost"))

        self.assertTrue(executor.bad_state_is_set)
        self.assertTrue(first.done())
        self.assertFalse(second.done())
        self.assertIn("callback-task", executor._tasks)


if __name__ == "__main__":
    unittest.main()
