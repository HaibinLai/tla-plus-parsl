"""Runtime probe for duplicate ``inputs`` dependency collection."""

import unittest
from concurrent.futures import Future

from parsl.dataflow.dependency_resolvers import DEEP_DEPENDENCY_RESOLVER
from parsl.dataflow.dflow import DataFlowKernel


class InputDependencyDuplicateRuntimeTest(unittest.TestCase):
    def test_inputs_future_is_gathered_twice_currently(self):
        kernel = DataFlowKernel.__new__(DataFlowKernel)
        kernel.dependency_resolver = DEEP_DEPENDENCY_RESOLVER
        dependency = Future()

        gathered = kernel._gather_all_deps((), {"inputs": [dependency]})

        self.assertEqual(gathered, [dependency, dependency])


if __name__ == "__main__":
    unittest.main()
