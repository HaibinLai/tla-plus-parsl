"""Runtime probes for malformed and heartbeat manager messages."""

import pickle
import unittest
from unittest.mock import patch

import zmq

from parsl.executors.high_throughput.interchange import Interchange, PKL_HEARTBEAT_CODE


class FakeManagerSocket:
    def __init__(self, parts):
        self.parts = parts
        self.replies = []

    def recv_multipart(self):
        return self.parts

    def send_multipart(self, frames):
        self.replies.append(frames)


class HtexManagerMessageRuntimeTest(unittest.TestCase):
    def interchange_with(self, parts):
        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = FakeManagerSocket(parts)
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interchange._ready_managers = {
            b"manager-1": {
                "last_heartbeat": 10,
                "active": True,
                "tasks": [],
            }
        }
        return interchange

    def test_malformed_manager_message_is_ignored_without_state_change(self):
        interchange = self.interchange_with([b"manager-1", b"not-a-pickle"])

        interchange.process_manager_socket_message(set(), None, object())

        self.assertEqual(interchange._ready_managers[b"manager-1"]["last_heartbeat"], 10)
        self.assertEqual(interchange.manager_sock.replies, [])

    def test_heartbeat_updates_timestamp_and_replies(self):
        message = pickle.dumps({"type": "heartbeat"})
        interchange = self.interchange_with([b"manager-1", message])

        with patch("parsl.executors.high_throughput.interchange.time.time", return_value=100):
            interchange.process_manager_socket_message(set(), None, object())

        self.assertEqual(interchange._ready_managers[b"manager-1"]["last_heartbeat"], 100)
        self.assertEqual(interchange.manager_sock.replies, [[b"manager-1", PKL_HEARTBEAT_CODE]])


if __name__ == "__main__":
    unittest.main()
