"""Runtime probe for an optional HTEX monitoring frame before a task result."""

import pickle
import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class FakeManagerSocket:
    def __init__(self, parts):
        self.parts = parts

    def recv_multipart(self):
        return self.parts


class HtexMonitoringBatchContinuationRuntimeTest(unittest.TestCase):
    def test_disabled_monitoring_aborts_later_result_currently(self):
        manager_id = b"manager-1"
        metadata = pickle.dumps({"type": "result"})
        monitoring = pickle.dumps({"type": "monitoring", "payload": ("event", {})})
        valid = pickle.dumps({"type": "result", "task_id": 2})

        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = FakeManagerSocket(
            [manager_id, metadata, monitoring, valid]
        )
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interchange._ready_managers = {
            manager_id: {"tasks": [2], "active": True},
        }

        with self.assertRaises(AssertionError):
            interchange.process_manager_socket_message(set(), None, object())

        # The optional monitoring frame aborts the loop before task 2 is handled.
        self.assertEqual([2], interchange._ready_managers[manager_id]["tasks"])


if __name__ == "__main__":
    unittest.main()
