"""Runtime bridge for malformed HTEX command-frame isolation."""

import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class FailingCommandSocket:
    def recv_pyobj(self):
        raise ValueError("malformed command frame")


class HtexCommandIngressIsolationRuntimeTest(unittest.TestCase):
    def test_malformed_command_frame_escapes_interchange_currently(self):
        interchange = Interchange.__new__(Interchange)
        interchange.command_channel = FailingCommandSocket()
        interchange.socks = {interchange.command_channel: zmq.POLLIN}

        with self.assertRaises(ValueError):
            interchange.process_command(monitoring_radio=None)


if __name__ == "__main__":
    unittest.main()
