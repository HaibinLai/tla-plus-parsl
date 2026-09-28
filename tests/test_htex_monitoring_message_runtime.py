"""Runtime probes for HTEX monitoring result messages."""

import pickle
import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class FakeManagerSocket:
    def __init__(self, parts):
        self.parts = parts
        self.replies = []

    def recv_multipart(self):
        return self.parts

    def send_multipart(self, frames):
        self.replies.append(frames)


class HtexMonitoringMessageRuntimeTest(unittest.TestCase):
    def test_monitoring_payload_without_radio_currently_asserts(self):
        manager_id = b"manager-1"
        metadata = pickle.dumps({"type": "result"})
        payload = pickle.dumps({"type": "monitoring", "payload": ("event", {})})
        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = FakeManagerSocket([manager_id, metadata, payload])
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interchange._ready_managers = {
            manager_id: {"tasks": [], "active": True},
        }
        with self.assertRaises(AssertionError):
            interchange.process_manager_socket_message(set(), None, object())


if __name__ == "__main__":
    unittest.main()
