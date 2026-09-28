"""Runtime probes for HTEX ResultsIncoming poll/receive semantics."""

import threading
import unittest
from unittest.mock import patch

import zmq

from parsl.executors.high_throughput.zmq_pipes import ResultsIncoming


class FakeSocket:
    def __init__(self, poll_result, frames=None):
        self.poll_result = poll_result
        self.frames = frames
        self.poll_calls = []
        self.closed = False

    def poll(self, timeout, flags):
        self.poll_calls.append((timeout, flags))
        return self.poll_result

    def recv_multipart(self):
        return self.frames

    def close(self):
        self.closed = True


class FakeContext:
    def __init__(self):
        self.terminated = False

    def term(self):
        self.terminated = True


class ResultsIncomingRuntimeTest(unittest.TestCase):
    def receiver_with(self, socket):
        receiver = ResultsIncoming.__new__(ResultsIncoming)
        receiver.results_receiver = socket
        receiver.zmq_context = FakeContext()
        return receiver

    def test_readable_socket_returns_multipart_frames(self):
        socket = FakeSocket(zmq.POLLIN, [b"route", b"payload"])
        receiver = self.receiver_with(socket)

        self.assertEqual(receiver.get(timeout_ms=25), [b"route", b"payload"])
        self.assertEqual(socket.poll_calls, [(25, zmq.POLLIN)])

    def test_poll_timeout_returns_none_without_receive(self):
        socket = FakeSocket(0)
        receiver = self.receiver_with(socket)

        self.assertIsNone(receiver.get(timeout_ms=10))
        self.assertEqual(socket.poll_calls, [(10, zmq.POLLIN)])

    def test_close_closes_socket_and_context(self):
        socket = FakeSocket(0)
        receiver = self.receiver_with(socket)

        receiver.close()

        self.assertTrue(socket.closed)
        self.assertTrue(receiver.zmq_context.terminated)


if __name__ == "__main__":
    unittest.main()
