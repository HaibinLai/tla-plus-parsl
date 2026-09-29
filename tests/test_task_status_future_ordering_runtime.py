"""Runtime probe for DFK task-status/Future completion ordering."""

import threading
import unittest

from parsl.dataflow.dflow import DataFlowKernel
from parsl.dataflow.states import States


class RecordingMemoizer:
    def update_memo_result(self, task_record, result):
        return None


class RecordingFuture:
    def __init__(self, task_record):
        self._update_lock = threading.RLock()
        self.task_record = task_record
        self.observed_status_at_set_result = None
        self.result_value = None

    def set_result(self, value):
        self.observed_status_at_set_result = self.task_record["status"]
        self.result_value = value


class TaskStatusFutureOrderingRuntimeTest(unittest.TestCase):
    def test_task_status_is_published_before_future_result(self):
        task_record = {"id": 1, "status": States.running, "time_returned": None}
        app_future = RecordingFuture(task_record)
        task_record["app_fu"] = app_future

        dfk = DataFlowKernel.__new__(DataFlowKernel)
        dfk.memoizer = RecordingMemoizer()
        dfk.wipe_task = lambda task_id: None
        dfk._update_task_state = lambda record, state: record.__setitem__("status", state)

        dfk._complete_task_result(task_record, States.exec_done, "ready")

        self.assertEqual(task_record["status"], States.exec_done)
        self.assertEqual(app_future.observed_status_at_set_result, States.exec_done)
        self.assertEqual(app_future.result_value, "ready")


if __name__ == "__main__":
    unittest.main()
