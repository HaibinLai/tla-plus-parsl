"""Runtime probe for ResultsIncoming.get racing with close()."""

import unittest

import zmq

from parsl.executors.high_throughput.zmq_pipes import ResultsIncoming


class ClosedSocket:
    def __init__(self):
        self.closed = False

    def poll(self, timeout, flags):
        if self.closed:
            raise zmq.error.ZMQError("Socket operation on non-socket")
        return 0

    def close(self):
        self.closed = True


class Context:
    def term(self):
        return None


class ResultsIncomingCloseRaceRuntimeTest(unittest.TestCase):
    def test_get_after_close_reaches_terminated_socket_currently(self):
        socket = ClosedSocket()
        receiver = ResultsIncoming.__new__(ResultsIncoming)
        receiver.results_receiver = socket
        receiver.zmq_context = Context()

        receiver.close()
        with self.assertRaises(zmq.error.ZMQError):
            receiver.get(timeout_ms=0)


if __name__ == "__main__":
    unittest.main()
