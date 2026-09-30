"""Runtime probe for the HTEX initial connection-probe timeout path."""

import threading
import unittest
from unittest import mock

from parsl.executors.high_throughput import process_worker_pool
from parsl.executors.high_throughput.process_worker_pool import Manager


class ProbeSocket:
    def __init__(self, recv_error=None):
        self.recv_error = recv_error
        self.sent = []

    def setsockopt(self, *_args):
        pass

    def bind(self, *_args):
        pass

    def connect(self, *_args):
        pass

    def send(self, message):
        self.sent.append(message)

    def recv(self):
        if self.recv_error is not None:
            raise self.recv_error
        return b"ack"


class ProbeContext:
    def __init__(self, results_socket, interchange_socket):
        self.results_socket = results_socket
        self.interchange_socket = interchange_socket
        self.calls = 0

    def socket(self, socket_type):
        self.calls += 1
        return self.results_socket if self.calls == 1 else self.interchange_socket


class ProbePoller:
    def register(self, *_args):
        pass

    def poll(self, **_kwargs):
        return []


class WorkerInitialProbeTimeoutRuntimeTest(unittest.TestCase):
    def test_probe_timeout_enters_blocking_recv_currently(self):
        results = ProbeSocket()
        interchange = ProbeSocket(BlockingIOError("probe reply unavailable"))
        manager = Manager.__new__(Manager)
        manager.zmq_context = ProbeContext(results, interchange)
        manager.uid = "manager-1"
        manager._ix_url = "tcp://127.0.0.1:1"
        manager.heartbeat_period = 1
        setup = threading.Event()

        with mock.patch.object(process_worker_pool.zmq, "Poller", ProbePoller):
            with self.assertRaises(BlockingIOError):
                manager.interchange_communicator(setup)

        self.assertTrue(setup.is_set())
        self.assertEqual(len(interchange.sent), 1)


if __name__ == "__main__":
    unittest.main()
