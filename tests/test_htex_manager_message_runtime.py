"""Runtime probes for malformed and heartbeat manager messages."""

import pickle
import unittest
from unittest.mock import patch

import zmq

from parsl.executors.high_throughput.interchange import Interchange, PKL_HEARTBEAT_CODE


class FakeManagerSocket:
    def __init__(self, parts):
        self.parts = parts
        self.replies = []

    def recv_multipart(self):
        return self.parts

    def send_multipart(self, frames):
        self.replies.append(frames)


class HtexManagerMessageRuntimeTest(unittest.TestCase):
    def interchange_with(self, parts):
        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = FakeManagerSocket(parts)
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interchange._ready_managers = {
            b"manager-1": {
                "last_heartbeat": 10,
                "active": True,
                "tasks": [],
            }
        }
        return interchange

    def test_malformed_manager_message_is_ignored_without_state_change(self):
        interchange = self.interchange_with([b"manager-1", b"not-a-pickle"])

        interchange.process_manager_socket_message(set(), None, object())

        self.assertEqual(interchange._ready_managers[b"manager-1"]["last_heartbeat"], 10)
        self.assertEqual(interchange.manager_sock.replies, [])

    def test_heartbeat_updates_timestamp_and_replies(self):
        message = pickle.dumps({"type": "heartbeat"})
        interchange = self.interchange_with([b"manager-1", message])

        with patch("parsl.executors.high_throughput.interchange.time.time", return_value=100):
            interchange.process_manager_socket_message(set(), None, object())

        self.assertEqual(interchange._ready_managers[b"manager-1"]["last_heartbeat"], 100)
        self.assertEqual(interchange.manager_sock.replies, [[b"manager-1", PKL_HEARTBEAT_CODE]])

    def test_registration_missing_python_version_escapes_currently(self):
        message = pickle.dumps({
            "type": "registration",
            "parsl_v": "current",
            "start_time": 0,
            "block_id": "block-1",
            "max_capacity": 1,
            "active": True,
            "draining": False,
        })
        interchange = self.interchange_with([b"manager-2", message])
        interchange.current_platform = {"python_v": "3.11.0", "parsl_v": "current"}
        interchange._check_python_mismatch = True

        with self.assertRaises(KeyError):
            interchange.process_manager_socket_message(set(), None, object())

    def test_registration_non_string_python_version_escapes_currently(self):
        message = pickle.dumps({
            "type": "registration",
            "python_v": 311,
            "parsl_v": "current",
            "start_time": 0,
            "block_id": "block-1",
            "max_capacity": 1,
            "active": True,
            "draining": False,
        })
        interchange = self.interchange_with([b"manager-2", message])
        interchange.current_platform = {"python_v": "3.11.0", "parsl_v": "current"}
        interchange._check_python_mismatch = True

        with self.assertRaises(AttributeError):
            interchange.process_manager_socket_message(set(), None, object())

    def test_registration_can_overwrite_reserved_tasks_state_currently(self):
        message = pickle.dumps({
            "type": "registration",
            "python_v": "3.11.0",
            "parsl_v": "current",
            "start_time": 0,
            "block_id": "block-1",
            "max_capacity": 1,
            "active": True,
            "draining": False,
            "tasks": "poisoned",
        })
        interchange = self.interchange_with([b"manager-2", message])
        interchange.current_platform = {"python_v": "3.11.0", "parsl_v": "current"}
        interchange._check_python_mismatch = True
        interchange.connected_block_history = []
        interchange._send_monitoring_info = lambda radio, manager: None

        interesting = set()
        interchange.process_manager_socket_message(interesting, None, object())

        self.assertIn(b"manager-2", interesting)
        self.assertEqual(interchange._ready_managers[b"manager-2"]["tasks"], "poisoned")

    def test_registration_with_null_block_id_escapes_assertion_currently(self):
        message = pickle.dumps({
            "type": "registration",
            "python_v": "3.11.0",
            "parsl_v": "current",
            "start_time": 0,
            "block_id": None,
            "max_capacity": 1,
            "active": True,
            "draining": False,
        })
        interchange = self.interchange_with([b"manager-2", message])
        interchange.current_platform = {"python_v": "3.11.0", "parsl_v": "current"}
        interchange._check_python_mismatch = True
        interchange.connected_block_history = []
        interchange._send_monitoring_info = lambda radio, manager: None

        with self.assertRaises(AssertionError):
            interchange.process_manager_socket_message(set(), None, object())


if __name__ == "__main__":
    unittest.main()
