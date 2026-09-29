"""Runtime probe for malformed-but-pickleable HTEX task batches."""

import pickle
import threading
import unittest
from unittest.mock import patch

import zmq

from parsl.executors.high_throughput.process_worker_pool import Manager


class ShapeSocket:
    def __init__(self, receives):
        self.receives = list(receives)

    def setsockopt(self, *args):
        return None

    def bind(self, address):
        return None

    def connect(self, address):
        return None

    def send(self, value):
        return None

    def recv(self):
        if not self.receives:
            raise AssertionError("worker communicator requested another frame")
        return self.receives.pop(0)

    def close(self):
        return None


class ShapeContext:
    def __init__(self, ix_socket):
        self.ix_socket = ix_socket
        self.count = 0

    def socket(self, socket_type):
        self.count += 1
        return ShapeSocket([]) if self.count == 1 else self.ix_socket


class ShapePoller:
    def __init__(self):
        self.registered = []
        self.poll_count = 0

    def register(self, socket, event):
        self.registered.append(socket)

    def poll(self, timeout=None):
        self.poll_count += 1
        if self.poll_count <= 2:
            return [(self.registered[-1], zmq.POLLIN)]
        return []


class HtexWorkerTaskBatchShapeRuntimeTest(unittest.TestCase):
    def test_pickleable_dict_shape_aborts_later_valid_batch_currently(self):
        malformed_shape = pickle.dumps({"task_id": 7})
        valid_batch = pickle.dumps([{"task_id": 99}])
        ix_socket = ShapeSocket([b"probe-reply", malformed_shape, valid_batch])

        manager = Manager.__new__(Manager)
        manager.zmq_context = ShapeContext(ix_socket)
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

        with patch("parsl.executors.high_throughput.process_worker_pool.zmq.Poller", ShapePoller):
            with self.assertRaises((KeyError, TypeError, IndexError)):
                manager.interchange_communicator(threading.Event())

        self.assertEqual(ix_socket.receives, [valid_batch])


if __name__ == "__main__":
    unittest.main()
