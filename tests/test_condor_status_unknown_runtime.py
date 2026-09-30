"""Runtime probe for Condor status projection of stale requested IDs."""

import unittest

from parsl.providers.condor.condor import CondorProvider


class CondorStatusUnknownRuntimeTest(unittest.TestCase):
    def test_untracked_requested_id_raises_key_error_currently(self):
        provider = CondorProvider.__new__(CondorProvider)
        provider.resources = {}
        provider.cmd_chunk_size = 100
        provider.execute_wait = lambda command: (0, "", "")

        with self.assertRaises(KeyError):
            provider.status(["stale-job"])


if __name__ == "__main__":
    unittest.main()
