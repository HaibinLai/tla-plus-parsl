"""Runtime probe for authenticated malformed UDP monitoring payloads."""

import hashlib
import hmac
import pickle
import threading
import unittest
from unittest.mock import patch

from parsl.monitoring.radios.udp_router import MonitoringRouter


class SocketDouble:
    def __init__(self, packet):
        self.packet = packet

    def recvfrom(self, _size):
        return self.packet, ("127.0.0.1", 54321)


class MonitoringUDPPickleRuntimeTest(unittest.TestCase):
    def test_authenticated_malformed_pickle_escapes_router_currently(self):
        key = b"monitoring-test-key"
        payload = b"not-a-pickle"
        digest = hmac.new(key, payload, hashlib.sha256).digest()
        router = MonitoringRouter.__new__(MonitoringRouter)
        router.udp_sock = SocketDouble(digest + payload)
        router.hmac_key = key
        router.hmac_digest = "sha256"
        router.target_radio = type("Radio", (), {"send": lambda self, value: None})()

        with patch("parsl.monitoring.radios.udp_router.logger"):
            with self.assertRaises((pickle.UnpicklingError, EOFError, AttributeError)):
                router.process_message()


if __name__ == "__main__":
    unittest.main()
