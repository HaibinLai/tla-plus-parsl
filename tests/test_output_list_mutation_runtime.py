"""Runtime probe for caller-owned output-list mutation during stage-out setup."""

import unittest
from concurrent.futures import Future
from types import SimpleNamespace

from parsl.data_provider.files import File
from parsl.dataflow.dflow import DataFlowKernel


class OutputListMutationRuntimeTest(unittest.TestCase):
    def test_add_output_deps_replaces_caller_output_file_currently(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.check_staging_inhibited = lambda kwargs: False
        kernel.data_manager = SimpleNamespace(
            stage_out=lambda file, executor, app_future: None,
            replace_task_stage_out=lambda file, func, executor: func,
        )
        application = Future()
        application.tid = 1
        original = File("file:///tmp/output")
        outputs = [original]
        kwargs = {"outputs": outputs}

        kernel._add_output_deps("exec", (), kwargs, application, lambda: "ok")

        self.assertIsNot(outputs[0], original)
        self.assertEqual(outputs[0].url, original.url)


if __name__ == "__main__":
    unittest.main()
