"""Probe bad-state propagation when a completed Future precedes a pending one."""

import threading
import unittest
from concurrent.futures import Future

from parsl.executors.errors import BadStateException
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


class BlockProviderBadStateOrderRuntimeTest(unittest.TestCase):
    def test_completed_future_can_abort_failure_sweep(self):
        executor = DummyBlockExecutor()
        executor._executor_bad_state = threading.Event()
        executor._executor_exception = None
        completed = Future()
        completed.set_result("already done")
        pending = Future()
        executor._tasks = {"done": completed, "pending": pending}

        with self.assertRaises(Exception) as caught:
            executor.set_bad_state_and_fail_all(RuntimeError("provider lost"))

        self.assertEqual(type(caught.exception).__name__, "InvalidStateError")
        self.assertTrue(executor.bad_state_is_set)
        self.assertTrue(completed.done())
        self.assertFalse(pending.done())

    def test_all_pending_futures_are_failed_when_no_completed_entry_intervenes(self):
        executor = DummyBlockExecutor()
        executor._executor_bad_state = threading.Event()
        executor._executor_exception = None
        first = Future()
        second = Future()
        executor._tasks = {"first": first, "second": second}
        executor.set_bad_state_and_fail_all(RuntimeError("provider lost"))

        self.assertIsInstance(first.exception(), BadStateException)
        self.assertIsInstance(second.exception(), BadStateException)


if __name__ == "__main__":
    unittest.main()
