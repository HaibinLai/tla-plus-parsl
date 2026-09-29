"""Runtime probes for the HTEX ZMQ connection probe helper."""

import unittest

from parsl.executors.high_throughput.probe import probe_addresses


class ProbeAddressesRuntimeTest(unittest.TestCase):
    def test_empty_candidate_set_is_rejected(self):
        with self.assertRaises(ValueError):
            probe_addresses(None, set())

    def test_unresponsive_candidate_times_out(self):
        import zmq

        context = zmq.Context()
        try:
            with self.assertRaises(ConnectionError):
                probe_addresses(
                    context,
                    {"tcp://127.0.0.1:1"},
                    timeout_ms=1,
                )
        finally:
            context.term()


if __name__ == "__main__":
    unittest.main()
