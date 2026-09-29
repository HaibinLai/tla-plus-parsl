"""Runtime probe for corrupt HTEX worker task pickle frames."""

import pickle
import threading
import unittest
from unittest.mock import patch

import zmq

from parsl.executors.high_throughput.process_worker_pool import Manager


class FakeSocket:
    def __init__(self, receives=None):
        self.receives = list(receives or [])
        self.sent = []

    def setsockopt(self, *args):
        return None

    def bind(self, address):
        return None

    def connect(self, address):
        return None

    def send(self, value):
        self.sent.append(value)

    def recv(self):
        if not self.receives:
            raise AssertionError("worker communicator requested another frame")
        return self.receives.pop(0)

    def close(self):
        return None


class FakeContext:
    def __init__(self, ix_socket):
        self.ix_socket = ix_socket
        self.socket_count = 0

    def socket(self, socket_type):
        self.socket_count += 1
        if self.socket_count == 1:
            return FakeSocket()
        return self.ix_socket


class FakePoller:
    instance = None

    def __init__(self):
        self.registered = []
        self.poll_count = 0
        FakePoller.instance = self

    def register(self, socket, event):
        self.registered.append(socket)

    def poll(self, timeout=None):
        self.poll_count += 1
        # First poll receives the connection-probe reply; second receives the
        # corrupt task frame and fails before a later valid batch can arrive.
        if self.poll_count <= 2:
            return [(self.registered[-1], zmq.POLLIN)]
        return []


class HtexWorkerTaskFrameContinuationRuntimeTest(unittest.TestCase):
    def test_corrupt_task_frame_stops_later_batch_currently(self):
        ix_socket = FakeSocket([
            b"probe-reply",
            b"not-an-outer-pickle",
            pickle.dumps([{"task_id": 99}]),
        ])
        manager = Manager.__new__(Manager)
        manager.zmq_context = FakeContext(ix_socket)
        manager._ix_url = "tcp://127.0.0.1:1"
        manager.uid = "manager-1"
        manager.block_id = "block-1"
        manager.heartbeat_period = 1
        manager.heartbeat_threshold = 10
        manager.drain_time = float("inf")
        manager._stop_event = threading.Event()
        manager.ready_worker_count = type("Counter", (), {"value": 0})()
        manager.pending_task_queue = type("Queue", (), {"qsize": lambda self: 0})()
        manager.task_scheduler = type("Scheduler", (), {"put_task": lambda self, task: None})()
        manager.create_reg_message = lambda: {"type": "registration"}

        with patch("parsl.executors.high_throughput.process_worker_pool.zmq.Poller", FakePoller):
            with self.assertRaises((pickle.UnpicklingError, EOFError, ValueError)):
                manager.interchange_communicator(threading.Event())

        self.assertEqual(FakePoller.instance.poll_count, 2)
        self.assertEqual(ix_socket.receives, [pickle.dumps([{"task_id": 99}])])


if __name__ == "__main__":
    unittest.main()
