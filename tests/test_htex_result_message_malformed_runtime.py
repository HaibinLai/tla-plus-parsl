"""Runtime probe for malformed HTEX manager result frames."""

import pickle
import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class FakeManagerSocket:
    def __init__(self, parts):
        self.parts = parts

    def recv_multipart(self):
        return self.parts


class HtexResultMessageMalformedRuntimeTest(unittest.TestCase):
    def test_corrupt_result_frame_escapes_processing_loop_currently(self):
        manager_id = b"manager-1"
        metadata = pickle.dumps({"type": "result"})
        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = FakeManagerSocket(
            [manager_id, metadata, b"not-a-pickle-result"]
        )
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interchange._ready_managers = {
            manager_id: {"tasks": [], "active": True},
        }

        with self.assertRaises((pickle.UnpicklingError, EOFError, ValueError)):
            interchange.process_manager_socket_message(set(), None, object())


if __name__ == "__main__":
    unittest.main()
