"""Runtime bridge for an independent stage-out completing after app cancellation."""

import unittest
from concurrent.futures import Future
from types import SimpleNamespace

from parsl.app.futures import DataFuture
from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File


class IndependentTransferProvider:
    def __init__(self, transfer_future):
        self.transfer_future = transfer_future

    def can_stage_out(self, file):
        return True

    def stage_out(self, dm, executor, file, app_future):
        # This is the documented independent-transfer return shape.  The
        # provider deliberately does not gate completion on app_future.
        return self.transfer_future


class JoinStageOutCancellationRuntimeTest(unittest.TestCase):
    def test_transfer_can_publish_after_cancelled_application_currently(self):
        application = Future()
        transfer = Future()
        manager = DataManager(SimpleNamespace(
            executors={"fake": SimpleNamespace(
                storage_access=[IndependentTransferProvider(transfer)]
            )}
        ))

        stageout = manager.stage_out(File("noop:/tmp/output"), "fake", application)
        output = DataFuture(stageout, File("noop:/tmp/output"), tid=1)

        self.assertTrue(application.cancel())
        self.assertTrue(application.cancelled())
        self.assertFalse(output.done())

        # The current DataFuture follows the independent transfer Future, so a
        # callback that was already in flight can publish after app cancellation.
        transfer.set_result("late-stageout")
        self.assertTrue(output.done())
        self.assertEqual(output.result().url, "noop:/tmp/output")


if __name__ == "__main__":
    unittest.main()
