"""Runtime bridge for HTEX worker task/result socket priority."""

import pickle
import threading
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from parsl.executors.high_throughput import process_worker_pool


class FakeSocket:
    def __init__(self, name, manager):
        self.name = name
        self.manager = manager
        self.sent = []
        self.recv_count = 0

    def setsockopt(self, *args):
        return None

    def bind(self, *args):
        return None

    def connect(self, *args):
        return None

    def send(self, payload):
        self.sent.append(payload)

    def recv(self):
        self.recv_count += 1
        if self.name == "ix" and self.recv_count == 1:
            return b""  # connection probe reply
        if self.name == "ix":
            self.manager._stop_event.set()
            return pickle.dumps([{"task_id": 7, "context": {}}])
        raise AssertionError("the result socket should be starved in this iteration")

    def close(self):
        return None


class FakeContext:
    def __init__(self):
        self.manager = None
        self.sockets = []

    def socket(self, _kind):
        name = "results" if not self.sockets else "ix"
        sock = FakeSocket(name, self.manager)
        self.sockets.append(sock)
        return sock


class FakePoller:
    def __init__(self, context):
        self.context = context
        self.poll_count = 0

    def register(self, *_args):
        return None

    def poll(self, *_args, **_kwargs):
        self.poll_count += 1
        results, ix = self.context.sockets
        if self.poll_count == 1:
            return [(ix, process_worker_pool.zmq.POLLIN)]
        # Both channels are readable.  The current branch checks ix first.
        return [(ix, process_worker_pool.zmq.POLLIN),
                (results, process_worker_pool.zmq.POLLIN)]


class HtexWorkerPollPriorityRuntimeTest(unittest.TestCase):
    def test_task_socket_wins_when_both_channels_are_readable_currently(self):
        context = FakeContext()
        manager = process_worker_pool.Manager.__new__(process_worker_pool.Manager)
        context.manager = manager
        manager.zmq_context = context
        manager.uid = "manager"
        manager._ix_url = "tcp://unused"
        manager.heartbeat_period = 100
        manager.heartbeat_threshold = 100
        manager.drain_time = float("inf")
        manager._stop_event = threading.Event()
        manager.ready_worker_count = SimpleNamespace(value=0)
        manager.pending_task_queue = SimpleNamespace(qsize=lambda: 0)
        manager.task_scheduler = SimpleNamespace(put_task=lambda task: None)
        manager.create_reg_message = lambda: {
            "type": "registration", "python_v": "3.10", "parsl_v": "0",
            "start_time": 0, "block_id": "b0",
        }

        pair_setup = threading.Event()
        with patch.object(process_worker_pool.zmq, "Poller", lambda: FakePoller(context)):
            manager.interchange_communicator(pair_setup)

        results, _ = context.sockets
        self.assertEqual(results.recv_count, 0)


if __name__ == "__main__":
    unittest.main()
