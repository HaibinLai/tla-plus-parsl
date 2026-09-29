"""Runtime probe for invalid HTEX heartbeat parameters."""

import unittest

from parsl.executors.high_throughput.executor import HighThroughputExecutor


class HeartbeatParameterValidationRuntimeTest(unittest.TestCase):
    def test_constructor_accepts_nonpositive_heartbeat_values_currently(self):
        executor = HighThroughputExecutor(
            encrypted=False,
            heartbeat_period=0,
            heartbeat_threshold=-1,
        )

        self.assertEqual(executor.heartbeat_period, 0)
        self.assertEqual(executor.heartbeat_threshold, -1)


if __name__ == "__main__":
    unittest.main()
