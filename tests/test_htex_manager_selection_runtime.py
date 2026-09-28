"""Runtime probes for HTEX manager selection strategies."""

import unittest

from parsl.executors.high_throughput.manager_selector import (
    BlockIdManagerSelector,
    RandomManagerSelector,
)


class HtexManagerSelectionRuntimeTest(unittest.TestCase):
    def setUp(self):
        self.ready = {
            b"m0": {"block_id": None},
            b"m1": {"block_id": "2"},
            b"m2": {"block_id": "10"},
        }
        self.managers = set(self.ready)

    def test_block_id_selector_uses_source_sort_key(self):
        selected = BlockIdManagerSelector().sort_managers(self.ready, self.managers)
        self.assertEqual(selected, [b"m0", b"m2", b"m1"])

    def test_random_selector_returns_each_ready_manager_once(self):
        selected = RandomManagerSelector().sort_managers(self.ready, self.managers)
        self.assertEqual(set(selected), self.managers)
        self.assertEqual(len(selected), len(self.managers))


if __name__ == "__main__":
    unittest.main()
