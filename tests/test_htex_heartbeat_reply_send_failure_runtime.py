"""Runtime bridge for HTEX heartbeat ACK send failure isolation."""

import threading
import unittest
import pickle

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class AckFailingManagerSocket:
    def recv_multipart(self):
        return [b"manager-1", pickle.dumps({"type": "heartbeat"})]

    def send_multipart(self, _parts):
        raise OSError("simulated manager heartbeat ACK failure")


class HtexHeartbeatReplySendFailureRuntimeTest(unittest.TestCase):
    def test_heartbeat_ack_failure_escapes_interchange_currently(self):
        interchange = Interchange.__new__(Interchange)
        interchange.manager_sock = AckFailingManagerSocket()
        manager_id = b"manager-1"
        interchange.socks = {interchange.manager_sock: zmq.POLLIN}
        interchange._ready_managers = {
            manager_id: {
                "last_heartbeat": 0,
                "tasks": [],
                "active": True,
            }
        }

        with self.assertRaises(OSError):
            interchange.process_manager_socket_message(
                set(), None, threading.Event()
            )

        self.assertGreater(interchange._ready_managers[manager_id]["last_heartbeat"], 0)


if __name__ == "__main__":
    unittest.main()
