"""Runtime probe for concurrent HTEX task-counter allocation."""

import threading
import unittest

from parsl.executors.high_throughput.executor import HighThroughputExecutor


class CoordinatedCounter:
    def __init__(self):
        self.barrier = threading.Barrier(2)

    def __add__(self, other):
        self.barrier.wait(timeout=2)
        return 1


class RecordingQueue:
    def __init__(self):
        self.messages = []

    def put(self, message):
        self.messages.append(message)


class HtexSubmitCounterRaceRuntimeTest(unittest.TestCase):
    def test_concurrent_submitters_overwrite_same_task_id_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor._executor_bad_state = threading.Event()
        executor._task_counter = CoordinatedCounter()
        executor._tasks = {}
        executor.outgoing_q = RecordingQueue()

        errors = []

        def submit():
            try:
                executor.submit_payload({}, b"serialized-task")
            except Exception as exc:  # pragma: no cover - diagnostic path
                errors.append(exc)

        threads = [threading.Thread(target=submit) for _ in range(2)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=3)

        self.assertEqual(errors, [])
        self.assertEqual(executor._task_counter, 1)
        self.assertEqual(len(executor._tasks), 1)
        self.assertEqual(len(executor.outgoing_q.messages), 2)
        self.assertEqual([msg["task_id"] for msg in executor.outgoing_q.messages], [1, 1])


if __name__ == "__main__":
    unittest.main()
