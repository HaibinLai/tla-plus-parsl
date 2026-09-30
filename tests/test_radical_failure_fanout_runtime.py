"""Runtime probe for Radical-Pilot failure fan-out mutation safety."""

import unittest
from concurrent.futures import Future

from parsl.executors.radical.executor import RadicalPilotExecutor


class RadicalFailureFanoutRuntimeTest(unittest.TestCase):
    def test_callback_mutation_aborts_current_failure_sweep(self):
        executor = RadicalPilotExecutor.__new__(RadicalPilotExecutor)
        executor.future_tasks = {}

        first = Future()
        second = Future()
        executor.future_tasks["task-0"] = first
        executor.future_tasks["task-1"] = second
        first.add_done_callback(lambda _: executor.future_tasks.pop("task-0"))

        with self.assertRaisesRegex(RuntimeError, "dictionary changed size"):
            executor._fail_all_tasks(RuntimeError("pilot failure"))

        self.assertTrue(first.done())
        self.assertFalse(second.done())


if __name__ == "__main__":
    unittest.main()
