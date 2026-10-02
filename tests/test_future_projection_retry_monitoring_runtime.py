"""Runtime bridge for retried projection state and monitoring high-water."""

import datetime
import tempfile
import unittest

import parsl
from parsl import Config, python_app
from parsl.executors.threads import ThreadPoolExecutor
from parsl.monitoring.db_manager import Database, STATUS, WORKFLOW


attempts = {"count": 0}


@python_app
def monitored_retry_projection():
    attempts["count"] += 1
    if attempts["count"] == 1:
        raise RuntimeError("first physical attempt")
    return {"value": "ready"}


class FutureProjectionRetryMonitoringRuntimeTest(unittest.TestCase):
    def test_projection_and_status_rows_share_current_attempt(self):
        attempts["count"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)], retries=1)
        with parsl.load(config):
            projected = monitored_retry_projection()["value"]
            self.assertEqual(projected.result(), "ready")
        self.assertEqual(attempts["count"], 2)

        path = tempfile.mktemp(suffix=".db")
        database = Database("sqlite:///" + path)
        now = datetime.datetime.now()
        database.insert(
            table=WORKFLOW,
            messages=[{
                "run_id": "projection-run",
                "time_began": now,
                "host": "host",
                "user": "user",
                "rundir": "/tmp/run",
                "tasks_failed_count": 0,
                "tasks_completed_count": 1,
            }],
        )
        database.insert(
            table=STATUS,
            messages=[
                {"task_id": 9, "run_id": "projection-run", "task_status_name": "failed",
                 "timestamp": now, "try_id": 0},
                {"task_id": 9, "run_id": "projection-run", "task_status_name": "done",
                 "timestamp": now + datetime.timedelta(seconds=1), "try_id": 1},
                # A late old-attempt status must not replace the current row.
                {"task_id": 9, "run_id": "projection-run", "task_status_name": "running",
                 "timestamp": now + datetime.timedelta(seconds=2), "try_id": 0},
            ],
        )
        rows = database.session.execute(database.meta.tables[STATUS].select()).fetchall()
        current = max((row for row in rows if row.task_id == 9), key=lambda row: row.try_id)
        self.assertEqual(current.try_id, 1)
        self.assertEqual(current.task_status_name, "done")


if __name__ == "__main__":
    unittest.main()
