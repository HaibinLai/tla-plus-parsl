"""Evidence that CommandClient.run currently ignores max_retries."""

import threading
import unittest

from parsl.executors.high_throughput.zmq_pipes import CommandClient


class FailingSocket:
    def __init__(self):
        self.sends = 0

    def send_pyobj(self, message, copy=True):
        self.sends += 1
        raise OSError("transient send failure")


class CommandClientMaxRetriesRuntimeTest(unittest.TestCase):
    def test_max_retries_does_not_retry_send_failure(self):
        for configured in (0, 2):
            socket = FailingSocket()
            client = CommandClient.__new__(CommandClient)
            client.zmq_socket = socket
            client._lock = threading.Lock()
            client.ok = True

            with self.assertRaises(OSError):
                client.run("request", max_retries=configured)
            self.assertEqual(socket.sends, 1)


if __name__ == "__main__":
    unittest.main()
