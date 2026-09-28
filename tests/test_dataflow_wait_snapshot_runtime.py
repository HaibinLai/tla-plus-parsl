"""Runtime probe for wait_for_current_tasks snapshot behavior."""

import unittest
from concurrent.futures import Future

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.states import States


class LateTaskDict(dict):
    def __init__(self, initial, late_record):
        super().__init__(initial)
        self.late_record = late_record
        self.snapshot_calls = 0

    def values(self):
        self.snapshot_calls += 1
        values = list(super().values())
        if self.snapshot_calls == 1:
            self["late"] = self.late_record
        return values


class DataFlowWaitSnapshotRuntimeTest(unittest.TestCase):
    def test_task_added_after_snapshot_is_not_waited_currently(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        initial = {
            "app_fu": Future(),
            "status": States.exec_done,
        }
        initial["app_fu"].set_result("done")
        late = {
            "app_fu": Future(),
            "status": States.pending,
        }
        kernel.tasks = LateTaskDict({"initial": initial}, late)

        kernel.wait_for_current_tasks()

        self.assertIn("late", kernel.tasks)
        self.assertFalse(kernel.tasks["late"]["app_fu"].done())
        self.assertEqual(kernel.tasks["late"]["status"], States.pending)


if __name__ == "__main__":
    unittest.main()
