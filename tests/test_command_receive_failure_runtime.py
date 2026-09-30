"""Runtime probe for CommandClient response deserialization failure handling."""

import threading
import unittest

import zmq

from parsl.executors.high_throughput.zmq_pipes import CommandClient


class ReceiveFailureSocket:
    def __init__(self):
        self.sent = []

    def poll(self, timeout, flags):
        return zmq.POLLOUT if flags == zmq.POLLOUT else zmq.POLLIN

    def send_pyobj(self, message, copy=True):
        self.sent.append(message)

    def recv_pyobj(self):
        raise ValueError("corrupt response pickle")


class CommandReceiveFailureRuntimeTest(unittest.TestCase):
    def test_receive_decode_failure_leaves_client_healthy_currently(self):
        client = CommandClient.__new__(CommandClient)
        client.zmq_socket = ReceiveFailureSocket()
        client._lock = threading.Lock()
        client.ok = True

        with self.assertRaises(ValueError):
            client.run("status", timeout_s=1)

        self.assertTrue(client.ok)


if __name__ == "__main__":
    unittest.main()
