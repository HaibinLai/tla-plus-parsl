"""Runtime probe for HTEX address_probe_timeout command propagation."""

import unittest

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.providers import LocalProvider


class HtexAddressProbeTimeoutRuntimeTest(unittest.TestCase):
    def test_explicit_zero_is_dropped_from_worker_command_currently(self):
        executor = HighThroughputExecutor(
            provider=LocalProvider(),
            address="127.0.0.1",
            address_probe_timeout=0,
            encrypted=False,
        )
        executor.logconf_path = None
        executor.initialize_scaling()

        # The worker then falls back to process_worker_pool's default timeout.
        self.assertNotIn("--address_probe_timeout=0", executor.launch_cmd)


if __name__ == "__main__":
    unittest.main()
