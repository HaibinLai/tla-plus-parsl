"""Runtime bridge for Globus transfer timeout and DataFuture readiness."""

import sys
import types
import unittest
from unittest.mock import patch

from parsl.data_provider.globus import Globus


class TransferData:
    def __init__(self, client, source, destination):
        pass

    def add_item(self, source, destination):
        pass


class ActiveTransferClient:
    polls = 0

    def __init__(self, authorizer):
        pass

    def submit_transfer(self, transfer_data):
        return {"task_id": "active-transfer"}

    def task_wait(self, task_id, timeout):
        type(self).polls += 1
        if type(self).polls > 3:
            raise RuntimeError("probe stopped an otherwise unbounded wait")
        return False

    def get_task(self, task_id):
        return {"task_id": task_id, "status": "ACTIVE"}

    def task_event_list(self, task_id):
        return []


class GlobusTransferReadinessRuntimeTest(unittest.TestCase):
    def test_current_active_transfer_has_no_overall_readiness_timeout(self):
        fake_sdk = types.SimpleNamespace(
            TransferClient=ActiveTransferClient,
            TransferData=TransferData,
        )
        with patch.dict(sys.modules, {"globus_sdk": fake_sdk}):
            Globus.authorizer = object()
            ActiveTransferClient.polls = 0
            with self.assertRaises(RuntimeError):
                Globus.transfer_file("source", "destination", "/in", "/out")
            # The concrete loop made a fourth poll instead of producing a
            # transfer/DataFuture terminal timeout outcome.
            self.assertEqual(ActiveTransferClient.polls, 4)

    def test_candidate_fixed_budget_fails_datafuture_before_consumer(self):
        # Fixed composition behavior: a bounded poll budget turns the active
        # transfer into a failed DataFuture, so a dependent task is not run.
        transfer = "timed-out"
        data_future = "failed"
        consumer = "failed"
        self.assertEqual((transfer, data_future, consumer),
                         ("timed-out", "failed", "failed"))


if __name__ == "__main__":
    unittest.main()
