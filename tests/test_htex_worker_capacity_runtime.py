"""Runtime probes for HTEX worker-capacity derivation."""

import unittest

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.providers import LocalProvider


class HtexWorkerCapacityRuntimeTest(unittest.TestCase):
    @staticmethod
    def _executor(**kwargs):
        provider = LocalProvider()
        provider.cores_per_node = kwargs.pop("cores_per_node")
        provider.mem_per_node = kwargs.pop("mem_per_node")
        return HighThroughputExecutor(
            provider=provider,
            address="127.0.0.1",
            encrypted=False,
            **kwargs,
        )

    def test_cpu_capacity_is_the_binding_resource(self):
        executor = self._executor(
            cores_per_node=6,
            mem_per_node=64,
            cores_per_worker=2,
            mem_per_worker=8,
            max_workers_per_node=8,
        )
        self.assertEqual(executor._workers_per_node, 3)

    def test_memory_capacity_is_the_binding_resource(self):
        executor = self._executor(
            cores_per_node=16,
            mem_per_node=10,
            cores_per_worker=1,
            mem_per_worker=4,
            max_workers_per_node=8,
        )
        self.assertEqual(executor._workers_per_node, 2)

    def test_accelerator_count_caps_workers(self):
        executor = self._executor(
            cores_per_node=16,
            mem_per_node=64,
            cores_per_worker=1,
            mem_per_worker=4,
            max_workers_per_node=8,
            available_accelerators=3,
        )
        self.assertEqual(executor._workers_per_node, 3)


if __name__ == "__main__":
    unittest.main()
