"""Runtime probe for LSF cores-per-node resource validation."""

import unittest

from parsl.providers.lsf.lsf import LSFProvider


class LSFResourceValidationRuntimeTest(unittest.TestCase):
    def test_negative_cores_per_node_produces_negative_node_count_currently(self):
        provider = LSFProvider(
            cores_per_block=4,
            cores_per_node=-2,
            request_by_nodes=False,
            init_blocks=0,
            min_blocks=0,
            max_blocks=1,
        )
        self.assertEqual(provider.nodes_per_block, -2)


if __name__ == "__main__":
    unittest.main()
