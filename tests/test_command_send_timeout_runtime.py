"""Probe CommandClient reuse after a timeout before sending a request."""

import threading
import unittest

import zmq

from parsl.executors.high_throughput.errors import CommandClientTimeoutError
from parsl.executors.high_throughput.zmq_pipes import CommandClient


class FakeSocket:
    def __init__(self):
        self.poll_results = [0, zmq.POLLOUT, zmq.POLLIN]
        self.sent = []

    def poll(self, timeout, flags):
        return self.poll_results.pop(0)

    def send_pyobj(self, message, copy=True):
        self.sent.append((message, copy))

    def recv_pyobj(self):
        return "reply"


class CommandClientSendTimeoutRuntimeTest(unittest.TestCase):
    def test_pre_send_timeout_leaves_client_reusable(self):
        client = CommandClient.__new__(CommandClient)
        client.zmq_socket = FakeSocket()
        client._lock = threading.Lock()
        client.ok = True

        with self.assertRaises(CommandClientTimeoutError):
            client.run("first", timeout_s=1)

        self.assertTrue(client.ok)
        self.assertEqual(client.zmq_socket.sent, [])
        self.assertEqual(client.run("second", timeout_s=1), "reply")
        self.assertEqual(client.zmq_socket.sent, [("second", True)])


if __name__ == "__main__":
    unittest.main()
