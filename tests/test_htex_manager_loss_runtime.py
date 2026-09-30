"""Runtime probe for heartbeat-driven manager loss reaching an HTEX Future."""

import pickle
import threading
import unittest
from concurrent.futures import Future
from unittest.mock import patch

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.executors.high_throughput.interchange import Interchange
from parsl.executors.high_throughput.errors import ManagerLost


class OutgoingMessages:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class IncomingBatch:
    def __init__(self, executor, batch):
        self.executor = executor
        self.batch = batch

    def get(self, timeout_ms=None):
        if self.batch is not None:
            batch, self.batch = self.batch, None
            return batch
        self.executor._result_queue_thread_exit.set()
        return None

    def close(self):
        return None


class HtexManagerLossRuntimeTest(unittest.TestCase):
    def test_expired_manager_failure_resolves_future_with_manager_lost(self):
        interchange = Interchange.__new__(Interchange)
        interchange.heartbeat_threshold = 10
        interchange._ready_managers = {
            b"manager-1": {
                "last_heartbeat": 89,
                "active": True,
                "tasks": [17],
                "hostname": "worker-host",
            }
        }
        interchange.results_outgoing = OutgoingMessages()
        interchange._send_monitoring_info = lambda radio, manager: None

        with patch(
            "parsl.executors.high_throughput.interchange.time.time", return_value=100
        ):
            interchange.expire_bad_managers({b"manager-1"}, monitoring_radio=None)

        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        loss_future = Future()
        executor._tasks = {17: loss_future}
        executor._loss_future = loss_future
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        executor.incoming_q = IncomingBatch(executor, [interchange.results_outgoing.messages[0]])

        executor._result_queue_worker()

        self.assertNotIn(17, executor._tasks)
        self.assertIsInstance(loss_future.exception(), ManagerLost)

    def test_expiring_one_manager_preserves_two_active_managers(self):
        interchange = Interchange.__new__(Interchange)
        interchange.heartbeat_threshold = 10
        interchange._ready_managers = {
            b"manager-1": {"last_heartbeat": 89, "active": True,
                           "tasks": [17], "hostname": "worker-1"},
            b"manager-2": {"last_heartbeat": 95, "active": True,
                           "tasks": [], "hostname": "worker-2"},
            b"manager-3": {"last_heartbeat": 96, "active": True,
                           "tasks": [], "hostname": "worker-3"},
        }
        interchange.results_outgoing = OutgoingMessages()
        interchange._send_monitoring_info = lambda radio, manager: None

        with patch(
            "parsl.executors.high_throughput.interchange.time.time", return_value=100
        ):
            interesting = set(interchange._ready_managers)
            interchange.expire_bad_managers(interesting, monitoring_radio=None)

        self.assertEqual(set(interchange._ready_managers),
                         {b"manager-2", b"manager-3"})
        self.assertEqual(interesting, {b"manager-2", b"manager-3"})
        self.assertEqual(len(interchange.results_outgoing.messages), 1)


if __name__ == "__main__":
    unittest.main()
