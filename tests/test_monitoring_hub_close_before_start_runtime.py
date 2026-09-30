"""Runtime probe for closing an unstarted MonitoringHub."""

import unittest

from parsl.monitoring.monitoring import MonitoringHub


class MonitoringHubCloseBeforeStartRuntimeTest(unittest.TestCase):
    def test_close_before_start_reads_missing_active_flag_currently(self):
        hub = MonitoringHub.__new__(MonitoringHub)

        with self.assertRaises(AttributeError):
            hub.close()


if __name__ == "__main__":
    unittest.main()

