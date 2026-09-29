"""Runtime probe for HTEX duplicate registration replacing in-flight state."""

import pickle
import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class RegistrationSocket:
    def __init__(self, manager_id, metadata):
        self.parts = [manager_id, pickle.dumps(metadata)]

    def recv_multipart(self):
        return self.parts

    def send_multipart(self, frames):
        pass


class HtexDuplicateRegistrationRuntimeTest(unittest.TestCase):
    def test_duplicate_registration_replaces_inflight_task_record_currently(self):
        manager_id = b"manager-1"
        metadata = {
            "type": "registration",
            "python_v": "3.11.0",
            "parsl_v": "current",
            "start_time": 1.0,
            "block_id": "block-1",
            "worker_count": 1,
            "max_capacity": 1,
        }
        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = RegistrationSocket(manager_id, metadata)
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interchange.current_platform = {"python_v": "3.11.0", "parsl_v": "current"}
        interchange._check_python_mismatch = True
        interchange._ready_managers = {}
        interchange.connected_block_history = []
        interchange._send_monitoring_info = lambda radio, manager: None

        interesting = set()
        interchange.process_manager_socket_message(interesting, None, object())
        interchange._ready_managers[manager_id]["tasks"] = [42]

        # The same manager identity registers again, as can happen after a
        # reconnect or duplicated registration frame.
        interchange.manager_sock.parts = [manager_id, pickle.dumps(metadata)]
        interchange.process_manager_socket_message(interesting, None, object())

        self.assertEqual(interchange._ready_managers[manager_id]["tasks"], [])


if __name__ == "__main__":
    unittest.main()
