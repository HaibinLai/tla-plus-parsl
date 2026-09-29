"""Runtime probe for Condor scheduler command chunk sizing."""

import unittest

from parsl.providers.condor.condor import _chunker


class CondorChunkSizeRuntimeTest(unittest.TestCase):
    def test_zero_chunk_size_silently_groups_everything_currently(self):
        self.assertEqual(list(_chunker(["job-a", "job-b"], 0)), [["job-a", "job-b"]])


if __name__ == "__main__":
    unittest.main()
