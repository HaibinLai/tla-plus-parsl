import threading
import unittest

from parsl.executors.high_throughput.executor import HighThroughputExecutor


class CoordinatedEvent:
    def __init__(self):
        self.checked = threading.Event()
        self.released = threading.Event()
        self.value = False

    def is_set(self):
        self.checked.set()
        self.released.wait(timeout=2)
        return False

    def set(self):
        self.value = True


class RecordingQueue:
    def __init__(self):
        self.messages = []

    def put(self, message):
        self.messages.append(message)


class BadStateSubmitRaceRuntimeTest(unittest.TestCase):
    def test_submit_can_insert_after_bad_state_failure_sweep_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        event = CoordinatedEvent()
        executor._executor_bad_state = event
        executor._executor_exception = RuntimeError("executor failed")
        executor._tasks = {}
        executor._task_counter = 0
        executor.outgoing_q = RecordingQueue()

        thread = threading.Thread(
            target=executor.submit_payload,
            args=({}, b"serialized-task"),
        )
        thread.start()
        self.assertTrue(event.checked.wait(timeout=2))

        # The failure sweep sees an empty registry, then bad state is set. The
        # submitter resumes after its stale admission check and inserts a task.
        executor.set_bad_state_and_fail_all(RuntimeError("executor failed"))
        event.released.set()
        thread.join(timeout=2)

        self.assertEqual(list(executor.tasks), [1])
        self.assertFalse(executor.tasks[1].done())


if __name__ == "__main__":
    unittest.main()
