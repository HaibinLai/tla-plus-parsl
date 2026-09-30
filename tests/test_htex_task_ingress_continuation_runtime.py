"""Runtime probe for malformed-then-valid HTEX task ingress."""

import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class FakeTaskSocket:
    def __init__(self):
        self.messages = [
            {"task_id": 1},
            {"task_id": 2, "context": {"resource_spec": {"priority": 0}}},
        ]

    def recv_pyobj(self):
        return self.messages.pop(0)


class HtexTaskIngressContinuationRuntimeTest(unittest.TestCase):
    def test_malformed_message_stops_before_following_valid_message_currently(self):
        socket = FakeTaskSocket()
        interchange = Interchange.__new__(Interchange)
        interchange.task_incoming = socket
        interchange.socks = {socket: zmq.POLLIN}
        interchange.pending_task_queue = set()

        with self.assertRaises(KeyError):
            interchange.process_task_incoming()

        self.assertEqual(len(socket.messages), 1)
        self.assertEqual(interchange.pending_task_queue, set())


if __name__ == "__main__":
    unittest.main()
