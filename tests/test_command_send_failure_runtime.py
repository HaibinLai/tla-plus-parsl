"""Runtime probe for CommandClient send failures leaving the client healthy."""

import unittest

from parsl.executors.high_throughput.errors import CommandClientBadError
from parsl.executors.high_throughput.zmq_pipes import CommandClient


class FailingSocket:
    def send_pyobj(self, message, copy=True):
        raise RuntimeError("send failed")


class CommandSendFailureRuntimeTest(unittest.TestCase):
    def test_send_error_leaves_ok_true_and_retries_failed_socket_currently(self):
        client = CommandClient.__new__(CommandClient)
        client.ok = True
        client.zmq_socket = FailingSocket()
        client._lock = __import__("threading").Lock()

        with self.assertRaises(RuntimeError):
            client.run("request")
        self.assertTrue(client.ok)

        with self.assertRaises(RuntimeError):
            client.run("request-again")

        with self.assertRaises(CommandClientBadError):
            # Candidate fixed behavior: a send exception marks the client bad.
            client.ok = False
            client.run("request-after-failure")


if __name__ == "__main__":
    unittest.main()
