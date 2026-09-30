"""Runtime bridge for AppFuture stdout/stderr return-shape semantics."""

import unittest
from concurrent.futures import Future

from parsl.app.futures import DataFuture
from parsl.dataflow.futures import AppFuture
from parsl.data_provider.files import File


def make_app_future(stdout, stderr):
    return AppFuture({"id": 1, "kwargs": {"stdout": stdout, "stderr": stderr}})


class AppFutureOutputStreamsRuntimeTest(unittest.TestCase):
    def test_scalar_and_tuple_values_are_exposed_unchanged(self):
        streams = ("stdout.txt", ("part-a", "part-b"), None)
        for value in streams:
            app_future = make_app_future(value, value)
            self.assertIs(app_future.stdout, value)
            self.assertIs(app_future.stderr, value)

    def test_installed_stageout_future_overrides_original_value(self):
        parent = Future()
        data_future = DataFuture(parent, File("file:///staged-output"), tid=1)
        app_future = make_app_future(("original-a", "original-b"), None)
        app_future._stdout_future = data_future

        self.assertIs(app_future.stdout, data_future)
        self.assertIsNone(app_future.stderr)


if __name__ == "__main__":
    unittest.main()
