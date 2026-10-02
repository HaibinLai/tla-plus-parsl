"""Runtime probe for worker drain deadlines under a wall-clock rollback."""

import threading
import types
import unittest
from unittest.mock import patch

import zmq

from parsl.executors.high_throughput import process_worker_pool as pool


class FakeSocket:
    def __init__(self, kind, owner):
        self.kind = kind
        self.owner = owner
        self.sent = []

    def setsockopt(self, *args):
        pass

    def bind(self, address):
        pass

    def connect(self, address):
        pass

    def send(self, payload):
        self.sent.append(payload)

    def send_multipart(self, parts):
        self.sent.append(parts)

    def recv(self):
        return b"connection-ok"

    def close(self):
        pass


class FakeContext:
    def __init__(self):
        self.owner = None
        self.sockets = []

    def socket(self, kind):
        sock = FakeSocket(kind, self.owner)
        self.sockets.append(sock)
        return sock


class OneTimeoutPoller:
    def __init__(self, owner):
        self.owner = owner
        self.calls = 0

    def register(self, socket, event):
        pass

    def poll(self, timeout=None):
        self.calls += 1
        self.owner._stop_event.set()
        return {}


class HtexWorkerDrainClockRuntimeTest(unittest.TestCase):
    def test_wall_clock_rollback_suppresses_due_drain_currently(self):
        context = FakeContext()
        worker = pool.Manager.__new__(pool.Manager)
        worker.zmq_context = context
        context.owner = worker
        worker._ix_url = "tcp://interchange"
        worker.uid = "manager"
        worker.heartbeat_period = 10**9
        worker.heartbeat_threshold = 10**9
        worker.drain_time = 102.0
        worker._stop_event = threading.Event()
        worker.pending_task_queue = type("Q", (), {"qsize": lambda self: 0})()
        worker.ready_worker_count = type("Count", (), {"value": 0})()
        worker.create_reg_message = lambda: {"type": "registration"}

        # The deadline was created at wall time 100, but the current reading
        # is 90 after a rollback; monotonic elapsed time would already be due.
        readings = iter([90.0, 90.0, 90.0, 90.0, 90.0])
        fake_time = types.SimpleNamespace(time=lambda: next(readings))
        with patch.object(pool.zmq, "Poller", lambda: OneTimeoutPoller(worker)), \
             patch.object(pool, "time", fake_time):
            pool.Manager.interchange_communicator.__wrapped__(worker, threading.Event())

        ix_socket = next(sock for sock in context.sockets if sock.kind == zmq.DEALER)
        self.assertFalse(any(b"drain" in message for message in ix_socket.sent))


if __name__ == "__main__":
    unittest.main()
