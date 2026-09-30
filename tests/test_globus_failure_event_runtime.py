"""Runtime probe for empty Globus failure-event responses."""

import sys
import types
import unittest
from unittest.mock import patch

from parsl.data_provider.globus import Globus


class FakeTransferData:
    def __init__(self, client, src_endpoint, dst_endpoint):
        self.items = []

    def add_item(self, src_path, dst_path):
        self.items.append((src_path, dst_path))


class FakeTransferClient:
    def __init__(self, authorizer=None):
        self.authorizer = authorizer

    def submit_transfer(self, transfer_data):
        return {"task_id": "failed-task"}

    def task_wait(self, task_id, timeout):
        return True

    def get_task(self, task_id):
        return {"task_id": task_id, "status": "FAILED"}

    def task_event_list(self, task_id):
        return types.SimpleNamespace(data=[])


class GlobusFailureEventRuntimeTest(unittest.TestCase):
    def test_failed_transfer_with_no_events_exposes_index_error_currently(self):
        fake_sdk = types.SimpleNamespace(
            TransferClient=FakeTransferClient,
            TransferData=FakeTransferData,
        )

        with patch.dict(sys.modules, {"globus_sdk": fake_sdk}):
            with self.assertRaises(IndexError):
                Globus.transfer_file("src-endpoint", "dst-endpoint", "/in", "/out")


if __name__ == "__main__":
    unittest.main()
