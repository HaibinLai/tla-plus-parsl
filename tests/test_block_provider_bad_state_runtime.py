"""Runtime probe for BlockProviderExecutor bad-state propagation."""

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


class BlockProviderBadStateRuntimeTest(unittest.TestCase):
    def test_bad_state_fails_outstanding_futures_and_records_cause(self):
        executor = DummyBlockExecutor()
        executor._executor_bad_state = threading.Event()
        executor._executor_exception = None
        first = Future()
        second = Future()
        executor._tasks = {"first": first, "second": second}
        cause = RuntimeError("provider lost")

        executor.set_bad_state_and_fail_all(cause)

        self.assertTrue(executor.bad_state_is_set)
        self.assertIs(executor.executor_exception, cause)
        self.assertIsInstance(first.exception(), BadStateException)
        self.assertIsInstance(second.exception(), BadStateException)


if __name__ == "__main__":
    unittest.main()
