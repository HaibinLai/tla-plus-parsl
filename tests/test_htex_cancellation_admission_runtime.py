"""Runtime probe for HTEX cancellation before dispatch."""

import threading
import unittest

from concurrent.futures import Future

from parsl.executors.high_throughput.executor import HighThroughputExecutor


class RecordingOutgoingQueue:
    def __init__(self):
        self.messages = []

    def put(self, message):
        self.messages.append(message)


class HtexCancellationAdmissionRuntimeTest(unittest.TestCase):
    def test_cancelled_future_remains_mapped_and_queued_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor._executor_bad_state = threading.Event()
        executor._task_counter = 0
        executor._tasks = {}
        executor.outgoing_q = RecordingOutgoingQueue()

        future = executor.submit_payload({}, b"serialized-task")
        self.assertTrue(future.cancel())

        # Current HTEX does not retract either the task-map entry or the wire
        # message after Future.cancel() succeeds.
        self.assertTrue(future.cancelled())
        self.assertIn(future.parsl_executor_task_id, executor.tasks)
        self.assertEqual(len(executor.outgoing_q.messages), 1)


if __name__ == "__main__":
    unittest.main()
