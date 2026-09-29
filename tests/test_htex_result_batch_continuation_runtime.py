"""Runtime probe for malformed HTEX result frames inside a mixed batch."""

import pickle
import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class FakeManagerSocket:
    def __init__(self, parts):
        self.parts = parts

    def recv_multipart(self):
        return self.parts


class HtexResultBatchContinuationRuntimeTest(unittest.TestCase):
    def test_malformed_frame_aborts_later_valid_result_currently(self):
        manager_id = b"manager-1"
        metadata = pickle.dumps({"type": "result"})
        malformed = b"not-a-pickle-result"
        valid = pickle.dumps({"type": "result", "task_id": 2})

        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = FakeManagerSocket(
            [manager_id, metadata, malformed, valid]
        )
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interchange._ready_managers = {
            manager_id: {"tasks": [1, 2], "active": True},
        }

        with self.assertRaises((pickle.UnpicklingError, EOFError, ValueError)):
            interchange.process_manager_socket_message(set(), None, object())

        # The malformed frame aborts the loop before task 2 can be removed.
        self.assertEqual([1, 2], interchange._ready_managers[manager_id]["tasks"])


if __name__ == "__main__":
    unittest.main()
