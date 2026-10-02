"""Runtime bridge for HTEX command-reply send failure isolation."""

import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class ReplyFailingCommandSocket:
    def recv_pyobj(self):
        return "CONNECTED_BLOCKS"

    def send_pyobj(self, _reply):
        raise OSError("simulated disconnected command client")


class HtexCommandReplySendFailureRuntimeTest(unittest.TestCase):
    def test_reply_send_failure_escapes_interchange_currently(self):
        interchange = Interchange.__new__(Interchange)
        interchange.command_channel = ReplyFailingCommandSocket()
        interchange.socks = {interchange.command_channel: zmq.POLLIN}
        interchange.connected_block_history = []

        with self.assertRaises(OSError):
            interchange.process_command(monitoring_radio=None)


if __name__ == "__main__":
    unittest.main()
