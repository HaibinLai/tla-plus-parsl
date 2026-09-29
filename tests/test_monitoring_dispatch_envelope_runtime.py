"""Runtime probe for malformed monitoring queue envelopes."""

import unittest

from parsl.monitoring.db_manager import DatabaseManager


class MonitoringDispatchEnvelopeRuntimeTest(unittest.TestCase):
    def test_malformed_queue_tuple_escapes_dispatch_currently(self):
        manager = DatabaseManager.__new__(DatabaseManager)

        with self.assertRaises(AssertionError):
            manager._dispatch_to_internal(("only-one-element",))


if __name__ == "__main__":
    unittest.main()
