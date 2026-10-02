"""Runtime probe for independent multi-output stage-out Future dependencies."""

import unittest
from concurrent.futures import Future
from types import SimpleNamespace
from unittest.mock import patch

from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File
from parsl.data_provider.rsync import in_task_stage_out_wrapper


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

    def test_three_outputs_share_atomic_application_gate(self):
        provider = FakeStaging()
        dfk = SimpleNamespace(executors={
            "exec": SimpleNamespace(storage_access=[provider]),
        })
        manager = DataManager(dfk)
        application = Future()
        outputs = [
            manager.stage_out(File(f"file:///tmp/output-{index}"), "exec", application)
            for index in range(3)
        ]

        self.assertEqual(len(outputs), 3)
        self.assertTrue(all(not output.done() for output in outputs))
        self.assertEqual([parent for _, parent in provider.parents],
                         [application, application, application])

        application.set_result("application complete")
        self.assertTrue(all(output.done() for output in outputs))

    def test_independent_rsync_outputs_can_publish_mixed_source_versions_currently(self):
        """The versioned TLA+ bridge captures the current mixed-publication boundary."""
        with self.subTest("source-version mismatch"):
            import tempfile
            from pathlib import Path

            with tempfile.TemporaryDirectory() as directory:
                first = Path(directory) / "first.txt"
                second = Path(directory) / "second.txt"
                first.write_bytes(b"version-0")
                second.write_bytes(b"version-0")
                first_file = File("file:///remote/first.txt")
                second_file = File("file:///remote/second.txt")
                first_file.local_path = str(first)
                second_file.local_path = str(second)
                published = []

                def copy_with_version_change(command):
                    if not published:
                        published.append(first.read_bytes())
                        first.write_bytes(b"version-1")
                    else:
                        second.write_bytes(b"version-1")
                        published.append(second.read_bytes())
                    return 0

                first_wrapped = in_task_stage_out_wrapper(
                    lambda: "first-result", first_file, None, "remote-host"
                )
                second_wrapped = in_task_stage_out_wrapper(
                    lambda: "second-result", second_file, None, "remote-host"
                )
                with patch("parsl.data_provider.rsync.os.system", side_effect=copy_with_version_change):
                    self.assertEqual(first_wrapped(), "first-result")
                    self.assertEqual(second_wrapped(), "second-result")

                self.assertEqual(published, [b"version-0", b"version-1"])


if __name__ == "__main__":
    unittest.main()
