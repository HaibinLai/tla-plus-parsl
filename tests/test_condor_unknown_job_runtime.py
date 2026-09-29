"""Runtime probe for Condor status lookup of a stale local job id."""

import unittest

from parsl.providers.condor.condor import CondorProvider


class CondorUnknownJobRuntimeTest(unittest.TestCase):
    def test_unknown_job_id_raises_key_error_currently(self):
        provider = CondorProvider.__new__(CondorProvider)
        provider.resources = {}
        provider._status = lambda: None

        with self.assertRaises(KeyError):
            provider.status(["stale-id"])


if __name__ == "__main__":
    unittest.main()
