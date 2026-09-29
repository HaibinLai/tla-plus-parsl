"""Runtime probe for MonitoringHub cleanup ordering and idempotence."""

import unittest
from unittest.mock import patch

from parsl.monitoring.monitoring import MonitoringHub


class CountingEvent:
    def __init__(self):
        self.calls = 0

    def set(self):
        self.calls += 1


class CountingQueue:
    def __init__(self):
        self.close_calls = 0
        self.join_calls = 0

    def close(self):
        self.close_calls += 1

    def join_thread(self):
        self.join_calls += 1


class MonitoringHubCloseRuntimeTest(unittest.TestCase):
    def test_close_is_idempotent_and_closes_queue_once(self):
        hub = MonitoringHub.__new__(MonitoringHub)
        hub.monitoring_hub_active = True
        hub.dbm_exit_event = CountingEvent()
        hub.dbm_proc = object()
        hub.resource_msgs = CountingQueue()

        with patch("parsl.monitoring.monitoring.join_terminate_close_proc") as join_proc:
            hub.close()
            hub.close()

        self.assertFalse(hub.monitoring_hub_active)
        self.assertEqual(hub.dbm_exit_event.calls, 1)
        self.assertEqual(join_proc.call_count, 1)
        self.assertEqual(hub.resource_msgs.close_calls, 1)
        self.assertEqual(hub.resource_msgs.join_calls, 1)


if __name__ == "__main__":
    unittest.main()
