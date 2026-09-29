"""Runtime probe for Slurm's strict batching compatibility helper."""

import unittest

from parsl.providers.slurm.slurm import batched


class SlurmBatchStrictRuntimeTest(unittest.TestCase):
    def test_incomplete_strict_batch_is_currently_accepted(self):
        # The Python < 3.12 fallback ignores strict=True and yields a short
        # final tuple instead of raising ValueError.
        self.assertEqual(list(batched([1, 2, 3], 2, strict=True)), [(1, 2), (3,)])


if __name__ == "__main__":
    unittest.main()
