"""Runtime probes for the HTEX command client's REQ/REP timeout lifecycle."""

import threading
import unittest

import zmq

from parsl.executors.high_throughput.errors import (
    CommandClientBadError,
    CommandClientTimeoutError,
)
from parsl.executors.high_throughput.zmq_pipes import CommandClient


class FakeSocket:
    def __init__(self, poll_results, reply=None):
        self.poll_results = list(poll_results)
        self.reply = reply
        self.sent = []

    def poll(self, timeout, flags):
        self.assert_flags = flags
        return self.poll_results.pop(0)

    def send_pyobj(self, message, copy=True):
        self.sent.append((message, copy))

    def recv_pyobj(self):
        return self.reply


class CommandClientRuntimeTest(unittest.TestCase):
    def client_with(self, socket):
        client = CommandClient.__new__(CommandClient)
        client.zmq_socket = socket
        client._lock = threading.Lock()
        client.ok = True
        return client

    def test_reply_completes_command(self):
        socket = FakeSocket([zmq.POLLOUT, zmq.POLLIN], reply="ok")
        client = self.client_with(socket)

        self.assertEqual(client.run({"command": "status"}, timeout_s=1), "ok")
        self.assertTrue(client.ok)
        self.assertEqual(len(socket.sent), 1)

    def test_response_timeout_poison_client_and_rejects_reuse(self):
        socket = FakeSocket([zmq.POLLOUT, 0])
        client = self.client_with(socket)

        with self.assertRaises(CommandClientTimeoutError):
            client.run("request", timeout_s=1)

        self.assertFalse(client.ok)
        with self.assertRaises(CommandClientBadError):
            client.run("request-again", timeout_s=1)
        self.assertEqual(len(socket.sent), 1)


if __name__ == "__main__":
    unittest.main()
