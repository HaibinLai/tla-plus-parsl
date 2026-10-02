"""Runtime probe for Radical-Pilot zero-master selector admission."""

import unittest

from parsl.executors.radical import executor as radical_executor


class RadicalMasterCountAdmissionRuntimeTest(unittest.TestCase):
    def test_zero_masters_make_cyclic_selector_index_empty_list_currently(self):
        executor = radical_executor.RadicalPilotExecutor.__new__(radical_executor.RadicalPilotExecutor)
        executor.masters = []
        selector = executor._cyclic_master_selector()

        with self.assertRaises(IndexError):
            next(selector)


if __name__ == "__main__":
    unittest.main()
