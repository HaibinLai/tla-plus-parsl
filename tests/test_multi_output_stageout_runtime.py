"""Runtime probe for independent multi-output stage-out Future dependencies."""

import unittest
from concurrent.futures import Future
from types import SimpleNamespace

from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File


class FakeStaging:
    def __init__(self):
        self.parents = []

    def can_stage_out(self, file):
        return True

    def stage_out(self, dm, executor, file, app_fu):
        future = Future()
        self.parents.append((file, app_fu))
        app_fu.add_done_callback(lambda _: future.set_result("application-gated"))
        return future


class MultiOutputStageOutRuntimeTest(unittest.TestCase):
    def test_each_output_stageout_waits_on_same_application_future(self):
        provider = FakeStaging()
        dfk = SimpleNamespace(executors={
            "exec": SimpleNamespace(storage_access=[provider]),
        })
        manager = DataManager(dfk)
        application = Future()
        first = manager.stage_out(File("file:///tmp/first"), "exec", application)
        second = manager.stage_out(File("file:///tmp/second"), "exec", application)

        self.assertIsNot(first, second)
        self.assertFalse(first.done())
        self.assertFalse(second.done())
        self.assertEqual([parent for _, parent in provider.parents],
                         [application, application])

        application.set_result("application complete")
        self.assertTrue(first.done())
        self.assertTrue(second.done())


if __name__ == "__main__":
    unittest.main()
