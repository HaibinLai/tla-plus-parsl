"""Runtime probe for monitoring batching under a wall-clock rollback."""

import queue
import unittest
from unittest.mock import patch

from parsl.monitoring.db_manager import DatabaseManager


class MonitoringBatchClockRuntimeTest(unittest.TestCase):
    def test_wall_clock_rollback_allows_batch_past_deadline_currently(self):
        manager = DatabaseManager.__new__(DatabaseManager)
        manager.batching_interval = 1
        manager.batching_threshold = 999

        messages = queue.Queue()
        messages.put("first")
        messages.put("second")

        # _get_messages_in_batch calls time.time() once for the start and once
        # at the top of each loop. The rollback keeps elapsed wall time below
        # the one-second interval while both messages are consumed.
        with patch(
            "parsl.monitoring.db_manager.time.time",
            side_effect=[100, 99, 99, 99],
        ), patch("parsl.monitoring.db_manager.logger.debug"):
            result = manager._get_messages_in_batch(messages)

        self.assertEqual(result, ["first", "second"])


if __name__ == "__main__":
    unittest.main()
