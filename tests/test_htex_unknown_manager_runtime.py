"""Runtime probes for unknown-manager message isolation."""

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


class HtexUnknownManagerRuntimeTest(unittest.TestCase):
    def interchange(self, metadata, *payloads):
        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = FakeManagerSocket(
            [b"unknown-manager", pickle.dumps(metadata), *payloads]
        )
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interchange._ready_managers = {}
        return interchange

    def test_unknown_heartbeat_is_ignored_without_reply(self):
        interchange = self.interchange({"type": "heartbeat"})

        interchange.process_manager_socket_message(set(), None, object())

        self.assertEqual(interchange._ready_managers, {})
        self.assertEqual(interchange.manager_sock.replies, [])

    def test_unknown_result_is_ignored_without_forwarding(self):
        interchange = self.interchange(
            {"type": "result"},
            pickle.dumps({"type": "result", "task_id": 7}),
        )

        interchange.process_manager_socket_message(set(), None, object())

        self.assertEqual(interchange._ready_managers, {})
        self.assertEqual(interchange.manager_sock.replies, [])


if __name__ == "__main__":
    unittest.main()
