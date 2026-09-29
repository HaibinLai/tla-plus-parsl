"""Runtime probe for CommandClient.run after close()."""

import threading
import unittest

import zmq

from parsl.executors.high_throughput.zmq_pipes import CommandClient


class ClosedSocket:
    def __init__(self):
        self.closed = False

    def send_pyobj(self, message, copy=True):
        if self.closed:
            raise zmq.error.ZMQError("Socket operation on non-socket")

    def close(self):
        self.closed = True


class Context:
    def term(self):
        return None


class CommandClientCloseRuntimeTest(unittest.TestCase):
    def test_run_after_close_reaches_terminated_socket_currently(self):
        client = CommandClient.__new__(CommandClient)
        client.zmq_socket = ClosedSocket()
        client.zmq_context = Context()
        client._lock = threading.Lock()
        client.ok = True

        client.close()
        self.assertTrue(client.ok)
        with self.assertRaises(zmq.error.ZMQError):
            client.run({})


if __name__ == "__main__":
    unittest.main()
