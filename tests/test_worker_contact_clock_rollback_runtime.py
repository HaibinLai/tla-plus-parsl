"""Runtime probe for worker-side heartbeat expiry after a wall-clock rollback."""

import threading
import itertools
import unittest
from unittest.mock import patch

from parsl.executors.high_throughput import process_worker_pool as pool


class FakeSocket:
    def __init__(self, name):
        self.name = name
        self.sent = []

    def setsockopt(self, *_args):
        return None

    def bind(self, _url):
        return None

    def connect(self, _url):
        return None

    def send(self, message):
        self.sent.append(message)

    def send_multipart(self, message):
        self.sent.append(message)

    def recv(self):
        return b"connection-ok"

    def close(self):
        return None


class FakeContext:
    def __init__(self):
        self.sockets = []

    def socket(self, _kind):
        sock = FakeSocket(f"sock-{len(self.sockets)}")
        self.sockets.append(sock)
        return sock


class FakePoller:
    def __init__(self, stop_event, ix_sock):
        self.stop_event = stop_event
        self.ix_sock = ix_sock
        self.polls = 0

    def register(self, *_args):
        return None

    def poll(self, **_kwargs):
        self.polls += 1
        if self.polls == 1:
            return [(self.ix_sock, 1)]
        # Let the method return after observing one timeout.  The stop event
        # is external cleanup; it must not be set by the stale wall-clock
        # expiry check itself.
        self.stop_event.set()
        return []


class TrackingEvent:
    def __init__(self):
        self._set = False
        self.set_calls = 0

    def is_set(self):
        return self._set

    def set(self):
        self._set = True
        self.set_calls += 1


class WorkerContactClockRollbackRuntimeTest(unittest.TestCase):
    def test_wall_clock_rollback_suppresses_worker_expiry_currently(self):
        worker = pool.Manager.__new__(pool.Manager)
        worker.zmq_context = FakeContext()
        worker._ix_url = "tcp://fake"
        worker.uid = "manager"
        worker.heartbeat_period = 2
        worker.heartbeat_threshold = 2
        worker.drain_time = float("inf")
        worker._stop_event = TrackingEvent()
        worker.create_reg_message = lambda: {"type": "registration"}
        worker.pending_task_queue = type("Q", (), {"qsize": lambda self: 0})()
        worker.ready_worker_count = type("Count", (), {"value": 0})()
        worker.task_scheduler = type("Scheduler", (), {"put_task": lambda self, task: None})()

        ix_sock = None

        # The first reading initializes last_interchange_contact at 100; the
        # timeout check then sees 90, despite two units of elapsed logical
        # time in the model.
        readings = itertools.chain(
            [100.0, 100.0, 90.0, 90.0, 90.0, 90.0],
            itertools.repeat(90.0),
        )
        with patch.object(pool.time, "time", side_effect=lambda: next(readings)):
            # Capture the interchange socket created by the fake context.
            def poller_factory():
                nonlocal ix_sock
                ix_sock = worker.zmq_context.sockets[1]
                return FakePoller(worker._stop_event, ix_sock)

            with patch.object(pool.zmq, "Poller", side_effect=poller_factory):
                pool.Manager.interchange_communicator.__wrapped__(
                    worker, threading.Event()
                )

        self.assertTrue(worker._stop_event.is_set())
        # The fake poller set this event once to terminate the probe loop.
        # A second call would mean that the method itself declared contact
        # loss; the stale wall-clock reading must not do that.
        self.assertEqual(worker._stop_event.set_calls, 1)


if __name__ == "__main__":
    unittest.main()
