"""Runtime probe for expired HTEX command-client poll deadlines."""

import threading
import unittest
from unittest.mock import patch

import zmq

from parsl.executors.high_throughput.errors import CommandClientTimeoutError
from parsl.executors.high_throughput.zmq_pipes import CommandClient


class DeadlineSocket:
    def __init__(self):
        self.poll_timeouts = []

    def poll(self, timeout, flags):
        self.poll_timeouts.append((timeout, flags))
        return 0

    def send_pyobj(self, message, copy=True):
        raise AssertionError("send must not occur after an expired preflight poll")


class CommandDeadlineRuntimeTest(unittest.TestCase):
    def test_expired_deadline_passes_negative_poll_timeout_currently(self):
        socket = DeadlineSocket()
        client = CommandClient.__new__(CommandClient)
        client.zmq_socket = socket
        client._lock = threading.Lock()
        client.ok = True

        # The second monotonic reading is later than the zero-second deadline.
        with patch("parsl.executors.high_throughput.zmq_pipes.time.monotonic", side_effect=[0.0, 0.1]):
            with self.assertRaises(CommandClientTimeoutError):
                client.run("request", timeout_s=0)

        self.assertEqual(len(socket.poll_timeouts), 1)
        self.assertLess(socket.poll_timeouts[0][0], 0)
        self.assertEqual(socket.poll_timeouts[0][1], zmq.POLLOUT)


if __name__ == "__main__":
    unittest.main()
