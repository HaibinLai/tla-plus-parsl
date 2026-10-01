"""Runtime bridge for decode-failure retry state and monitoring generation order."""

import datetime
import pickle
import tempfile
import threading
import unittest
from concurrent.futures import Future

from parsl.executors.high_throughput.executor import HighThroughputExecutor
from parsl.monitoring.db_manager import Database, STATUS, WORKFLOW


class OneBatchQueue:
    def __init__(self, batch):
        self.batch = batch

    def get(self, timeout_ms=None):
        if self.batch is None:
            raise AssertionError("result worker unexpectedly requested another batch")
        batch, self.batch = self.batch, None
        return batch

    def close(self):
        return None


class ResultDecodeRetryMonitoringRuntimeTest(unittest.TestCase):
    def test_decode_failure_and_old_monitoring_event_are_both_observable_currently(self):
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        task_future = Future()
        executor._tasks = {17: task_future}
        executor._executor_bad_state = threading.Event()
        executor._result_queue_thread_exit = threading.Event()
        executor.poll_period = 1
        corrupt = pickle.dumps({
            "type": "result",
            "task_id": 17,
            "result": b"02\nnot-a-pickle",
        })
        executor.incoming_q = OneBatchQueue([corrupt])

        with self.assertRaises(Exception):
            executor._result_queue_worker()
        self.assertFalse(task_future.done())
        self.assertNotIn(17, executor.tasks)

        with tempfile.TemporaryDirectory() as directory:
            database = Database("sqlite:///" + directory + "/monitoring.db")
            base = datetime.datetime.now()
            database.insert(table=WORKFLOW, messages=[{
                "run_id": "decode-retry",
                "time_began": base,
                "host": "host",
                "user": "user",
                "rundir": directory,
                "tasks_failed_count": 0,
                "tasks_completed_count": 0,
            }])

            # Attempt 1 reaches success, then a late attempt-0 success is
            # accepted by the append-only STATUS table with a newer timestamp.
            database.insert(table=STATUS, messages=[{
                "task_id": 17,
                "run_id": "decode-retry",
                "task_status_name": "succeeded",
                "timestamp": base + datetime.timedelta(seconds=1),
                "try_id": 1,
            }])
            database.insert(table=STATUS, messages=[{
                "task_id": 17,
                "run_id": "decode-retry",
                "task_status_name": "succeeded",
                "timestamp": base + datetime.timedelta(seconds=2),
                "try_id": 0,
            }])

            rows = database.session.execute(
                database.meta.tables[STATUS].select()
                .where(database.meta.tables[STATUS].c.task_id == 17)
                .order_by(database.meta.tables[STATUS].c.timestamp)
            ).fetchall()

        self.assertEqual([row.try_id for row in rows], [1, 0])
        self.assertEqual(rows[-1].try_id, 0)


if __name__ == "__main__":
    unittest.main()
