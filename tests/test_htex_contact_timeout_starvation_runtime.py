"""Runtime probe for HTEX contact timeout starvation by result traffic."""

import threading
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import zmq

from parsl.executors.high_throughput import process_worker_pool as pool


class FakeSocket:
    def __init__(self, kind, owner):
        self.kind = kind
        self.owner = owner
        self.recv_count = 0

    def setsockopt(self, *args):
        pass

    def bind(self, address):
        pass

    def connect(self, address):
        pass

    def send(self, payload):
        pass

    def recv(self):
        if self.kind == zmq.DEALER:
            return b"probe-reply"
        self.recv_count += 1
        if self.recv_count >= 3:
            self.owner._stop_event.set()
        return b"result-payload"

    def send_multipart(self, parts):
        pass

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

    def destroy(self):
        pass


class FakePoller:
    def __init__(self):
        self.ix_socket = None
        self.results_socket = None
        self.calls = 0

    def register(self, socket, event):
        if socket.kind == zmq.DEALER:
            self.ix_socket = socket
        else:
            self.results_socket = socket

    def poll(self, timeout=None):
        self.calls += 1
        if self.calls == 1:
            return {self.ix_socket: zmq.POLLIN}
        return {self.results_socket: zmq.POLLIN}


class HtexContactTimeoutRuntimeTest(unittest.TestCase):
    def test_result_socket_activity_skips_contact_timeout_currently(self):
        context = FakeContext()
        holder = pool.Manager.__new__(pool.Manager)
        holder.zmq_context = context
        context.owner = holder
        holder.uid = "manager"
        holder._ix_url = "tcp://interchange"
        holder.heartbeat_period = 10**9
        holder.heartbeat_threshold = 2
        holder.poll_period = 1
        holder.drain_time = float("inf")
        holder._stop_event = threading.Event()
        holder.pending_task_queue = SimpleNamespace(qsize=lambda: 0)
        holder.ready_worker_count = SimpleNamespace(value=0)
        holder.create_reg_message = lambda: {"type": "registration"}

        clock = iter(range(0, 1000))
        with patch.object(pool.zmq, "Poller", FakePoller), \
             patch.object(pool.time, "time", side_effect=lambda: next(clock)), \
             patch.object(pool.logger, "critical") as critical:
            holder.interchange_communicator(threading.Event())

        self.assertGreaterEqual(max(socket.recv_count for socket in context.sockets), 3)
        critical.assert_not_called()


if __name__ == "__main__":
    unittest.main()
