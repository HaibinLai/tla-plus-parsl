"""Runtime probe for Globus' unbounded ACTIVE-transfer polling loop."""

import sys
import types
import unittest
from unittest.mock import patch

from parsl.data_provider.globus import Globus


class FakeTransferData:
    def __init__(self, client, source, destination):
        pass

    def add_item(self, source, destination):
        pass


class FakeTransferClient:
    polls = 0

    def __init__(self, authorizer):
        pass

    def submit_transfer(self, transfer_data):
        return {"task_id": "transfer-active"}

    def task_wait(self, task_id, timeout):
        type(self).polls += 1
        if type(self).polls > 3:
            raise RuntimeError("probe stopped an otherwise unbounded wait")
        return False

    def get_task(self, task_id):
        return {"task_id": task_id, "status": "ACTIVE"}

    def task_event_list(self, task_id):
        return []


class GlobusTransferTimeoutRuntimeTest(unittest.TestCase):
    def test_active_transfer_keeps_polling_without_overall_deadline(self):
        fake_sdk = types.SimpleNamespace(
            TransferClient=FakeTransferClient,
            TransferData=FakeTransferData,
        )

        with patch.dict(sys.modules, {"globus_sdk": fake_sdk}):
            Globus.authorizer = object()
            FakeTransferClient.polls = 0
            with self.assertRaises(RuntimeError):
                Globus.transfer_file(
                    "source-endpoint", "destination-endpoint", "/input", "/output"
                )
            self.assertEqual(FakeTransferClient.polls, 4)


if __name__ == "__main__":
    unittest.main()
