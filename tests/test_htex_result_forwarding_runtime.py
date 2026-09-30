"""Runtime probe for manager-side HTEX result forwarding ownership."""

import pickle
import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class FakeManagerSocket:
    def __init__(self, parts):
        self.parts = parts

    def recv_multipart(self):
        return self.parts


class FailingOutgoing:
    def send_multipart(self, _parts):
        raise RuntimeError("result transport failed")


class HtexResultForwardingRuntimeTest(unittest.TestCase):
    def test_send_failure_removes_manager_task_before_forwarding_currently(self):
        manager_id = b"manager-forwarding"
        result = pickle.dumps({"type": "result", "task_id": 7})

        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = FakeManagerSocket([
            manager_id,
            pickle.dumps({"type": "result"}),
            result,
        ])
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interchange._ready_managers = {
            manager_id: {"tasks": [7], "idle_since": None, "active": True}
        }
        interchange.results_outgoing = FailingOutgoing()
        interchange._send_monitoring_info = lambda *_args: None

        with self.assertRaises(RuntimeError):
            interchange.process_manager_socket_message(set(), None, object())

        # The current remove-before-send ordering loses manager ownership.
        self.assertEqual(interchange._ready_managers[manager_id]["tasks"], [])


if __name__ == "__main__":
    unittest.main()
