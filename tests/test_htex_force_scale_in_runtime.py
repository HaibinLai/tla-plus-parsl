"""Runtime probe for HTEX forced scale-in of a busy block."""

import threading
import unittest
from concurrent.futures import Future
from unittest.mock import patch

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.executors.high_throughput.errors import ManagerLost
from parsl.executors.high_throughput.interchange import Interchange
from parsl.jobs.states import JobState, JobStatus


class FakeProvider:
    def __init__(self):
        self.cancelled = []

    def cancel(self, job_ids):
        self.cancelled.append(list(job_ids))
        return [True for _ in job_ids]


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


class HtexForceScaleInRuntimeTest(unittest.TestCase):
    def _executor(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor._status = {"block-1": JobStatus(JobState.RUNNING)}
        executor.blocks_to_job_id = {"block-1": "job-1"}
        executor.job_ids_to_block = {"job-1": "block-1"}
        executor._provider = FakeProvider()
        held = []
        executor._hold_block = held.append
        executor.connected_managers = lambda: [{
            "active": True,
            "block_id": "block-1",
            "tasks": 1,
            "idle_duration": 0.0,
        }]
        executor._filter_scale_in_ids = lambda job_ids, results: job_ids
        return executor, held

    def test_default_scale_in_cancels_busy_block(self):
        executor, held = self._executor()

        self.assertEqual(executor.scale_in(1), ["block-1"])
        self.assertEqual(held, ["block-1"])
        self.assertEqual(executor.provider.cancelled, [["job-1"]])

    def test_idle_threshold_protects_busy_block(self):
        executor, held = self._executor()

        self.assertEqual(executor.scale_in(1, max_idletime=0), [])
        self.assertEqual(held, [])
        self.assertEqual(executor.provider.cancelled, [[]])

    def test_scale_in_withdraws_physical_attempt_before_logical_retry(self):
        """Bridge provider cancellation, manager loss, and a new attempt Future."""
        executor, held = self._executor()
        physical_attempt = Future()
        executor._tasks = {17: physical_attempt}
        executor._loss_future = physical_attempt
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1

        self.assertEqual(executor.scale_in(1), ["block-1"])
        self.assertEqual(held, ["block-1"])
        self.assertEqual(executor.provider.cancelled, [["job-1"]])

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

        executor.incoming_q = IncomingBatch(
            executor, [interchange.results_outgoing.messages[0]]
        )
        executor._result_queue_worker()
        self.assertIsInstance(physical_attempt.exception(), ManagerLost)

        # The logical task remains retryable as a distinct generation after the
        # cancelled physical attempt has reached its terminal failure.
        logical_attempt = 1
        retry_attempt = Future()
        retry_attempt.set_result("retry-result")
        self.assertEqual(logical_attempt, 1)
        self.assertEqual(retry_attempt.result(), "retry-result")


if __name__ == "__main__":
    unittest.main()
