"""Runtime bridge for retry-attempt status rows and monitoring selection."""

import datetime
import tempfile
import unittest

from parsl.monitoring.db_manager import Database, STATUS, WORKFLOW


class ResultMonitoringAttemptRuntimeTest(unittest.TestCase):
    def test_monitoring_rows_keep_attempt_identity_for_current_selection(self):
        path = tempfile.mktemp(suffix=".db")
        database = Database("sqlite:///" + path)
        now = datetime.datetime.now()
        database.insert(
            table=WORKFLOW,
            messages=[
                {
                    "run_id": "run-1",
                    "time_began": now,
                    "host": "host",
                    "user": "user",
                    "rundir": "/tmp/run",
                    "tasks_failed_count": 0,
                    "tasks_completed_count": 0,
                }
            ],
        )
        for try_id, status in ((0, "failed"), (1, "done")):
            database.insert(
                table=STATUS,
                messages=[
                    {
                        "task_id": 7,
                        "run_id": "run-1",
                        "task_status_name": status,
                        "timestamp": now + datetime.timedelta(seconds=try_id),
                        "try_id": try_id,
                    }
                ],
            )

        rows = database.session.execute(database.meta.tables[STATUS].select()).fetchall()
        current = max(rows, key=lambda row: row.try_id)
        self.assertEqual(current.try_id, 1)
        self.assertEqual(current.task_status_name, "done")


if __name__ == "__main__":
    unittest.main()
