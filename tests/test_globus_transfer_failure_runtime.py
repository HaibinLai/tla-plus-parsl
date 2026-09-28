"""Runtime probe for Globus terminal failure responses without event details."""

import sys
import types
import unittest
from unittest.mock import patch

from parsl.data_provider.globus import Globus


class FakeTransferData:
    def __init__(self, client, source, destination):
        self.items = []

    def add_item(self, source, destination):
        self.items.append((source, destination))


class FakeTransferClient:
    def __init__(self, authorizer):
        pass

    def submit_transfer(self, transfer_data):
        return {"task_id": "transfer-1"}

    def task_wait(self, task_id, timeout):
        return True

    def get_task(self, task_id):
        return {"task_id": task_id, "status": "FAILED"}

    def task_event_list(self, task_id):
        return types.SimpleNamespace(data=[])


class GlobusTransferFailureRuntimeTest(unittest.TestCase):
    def test_failed_transfer_without_events_raises_index_error_currently(self):
        fake_sdk = types.SimpleNamespace(
            TransferClient=FakeTransferClient,
            TransferData=FakeTransferData,
        )

        with patch.dict(sys.modules, {"globus_sdk": fake_sdk}):
            Globus.authorizer = object()
            with self.assertRaises(IndexError):
                Globus.transfer_file(
                    "source-endpoint", "destination-endpoint", "/input", "/output"
                )


if __name__ == "__main__":
    unittest.main()
