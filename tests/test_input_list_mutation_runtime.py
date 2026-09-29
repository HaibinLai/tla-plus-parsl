"""Runtime probe for caller-owned input-list mutation during staging."""

import unittest

from parsl.dataflow.dflow import DataFlowKernel


class InputListMutationRuntimeTest(unittest.TestCase):
    def test_add_input_deps_mutates_caller_inputs_list_currently(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.check_staging_inhibited = lambda kwargs: False
        kernel.data_manager = type(
            "DataManagerDouble",
            (),
            {"optionally_stage_in": lambda self, value, func, executor: ("staged-input", func)},
        )()
        inputs = ["file:/input"]
        kwargs = {"inputs": inputs}

        kernel._add_input_deps("exec", (), kwargs, lambda value: value)

        # The current implementation rewrites kwargs['inputs'] in place, and
        # kwargs retains the same list object supplied by the caller.
        self.assertEqual(inputs, ["staged-input"])
        self.assertIsNot(kwargs["inputs"], inputs)


if __name__ == "__main__":
    unittest.main()
