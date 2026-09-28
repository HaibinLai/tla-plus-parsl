"""Runtime probe for Radical Pilot bulk-mode shutdown queue handling."""

import queue
import threading
import unittest

from parsl.executors.radical.executor import RadicalPilotExecutor


class RadicalBulkShutdownRuntimeTest(unittest.TestCase):
    def test_terminate_exits_collector_without_flushing_queued_task(self):
        executor = RadicalPilotExecutor.__new__(RadicalPilotExecutor)
        executor._terminate = threading.Event()
        executor._terminate.set()
        executor._bulk_queue = queue.Queue()
        executor._bulk_queue.put(object())
        executor._max_bulk_time = 3
        executor._min_bulk_time = 0.1

        executor._bulk_collector()

        self.assertEqual(executor._bulk_queue.qsize(), 1)


if __name__ == "__main__":
    unittest.main()
