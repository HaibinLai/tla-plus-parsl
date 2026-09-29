"""Runtime probe for HTEX cores_per_worker validation."""

import unittest

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.providers import LocalProvider


class HtexCoresPerWorkerRuntimeTest(unittest.TestCase):
    def test_zero_cores_per_worker_reaches_division_currently(self):
        provider = LocalProvider()
        provider.cores_per_node = 4

        with self.assertRaises(ZeroDivisionError):
            HighThroughputExecutor(
                provider=provider,
                cores_per_worker=0,
                encrypted=False,
            )


if __name__ == "__main__":
    unittest.main()
