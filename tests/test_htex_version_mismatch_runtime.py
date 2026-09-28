"""Runtime probe for HTEX manager registration version mismatch."""

import pickle
import threading
import unittest

import zmq

from parsl.executors.high_throughput.errors import VersionMismatch
from parsl.executors.high_throughput.interchange import Interchange
from parsl.serialize.facade import deserialize


class RegistrationSocket:
    def __init__(self, message):
        self.message = message
        self.sent = []

    def recv_multipart(self):
        return self.message

    def send_multipart(self, frames):
        self.sent.append(frames)


class ResultSink:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class HtexVersionMismatchRuntimeTest(unittest.TestCase):
    def test_mismatch_sends_fatal_result_without_ready_manager(self):
        meta = {
            "type": "registration",
            "python_v": "99.0.0",
            "parsl_v": "mismatch",
            "start_time": 1.0,
            "block_id": "block-1",
        }
        socket = RegistrationSocket([b"manager-1", pickle.dumps(meta)])
        sink = ResultSink()
        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = socket
        interchange.socks = {socket: zmq.POLLIN}
        interchange.current_platform = {"python_v": "3.10.0", "parsl_v": "current"}
        interchange._check_python_mismatch = True
        interchange._ready_managers = {}
        interchange.connected_block_history = []
        interchange.results_outgoing = sink
        interchange._send_monitoring_info = lambda radio, manager: None
        kill_event = threading.Event()

        interchange.process_manager_socket_message(set(), None, kill_event)

        self.assertTrue(kill_event.is_set())
        self.assertEqual(interchange._ready_managers, {})
        self.assertEqual(len(sink.messages), 1)
        fatal = pickle.loads(sink.messages[0])
        self.assertEqual(fatal["type"], "result")
        self.assertEqual(fatal["task_id"], -1)
        self.assertIsInstance(deserialize(fatal["exception"]), VersionMismatch)


if __name__ == "__main__":
    unittest.main()
