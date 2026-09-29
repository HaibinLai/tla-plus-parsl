"""Runtime bridge for append-only status history and timestamp ordering."""

import datetime
import tempfile
import unittest

from parsl.monitoring.db_manager import Database, STATUS, WORKFLOW


class MonitoringStatusHistoryRuntimeTest(unittest.TestCase):
    def test_out_of_order_inserts_preserve_history_and_latest_timestamp(self):
        with tempfile.TemporaryDirectory() as directory:
            database = Database("sqlite:///" + directory + "/monitoring.db")
            now = datetime.datetime.now()
            database.insert(
                table=WORKFLOW,
                messages=[{
                    "run_id": "run-history",
                    "time_began": now,
                    "host": "host",
                    "user": "user",
                    "rundir": directory,
                    "tasks_failed_count": 0,
                    "tasks_completed_count": 0,
                }],
            )

            events = [
                (now + datetime.timedelta(seconds=2), "timed_out"),
                (now + datetime.timedelta(seconds=1), "running"),
                (now + datetime.timedelta(seconds=3), "succeeded"),
            ]
            for timestamp, status in events:
                database.insert(table=STATUS, messages=[{
                    "task_id": 11,
                    "run_id": "run-history",
                    "task_status_name": status,
                    "timestamp": timestamp,
                    "try_id": 0,
                }])

            rows = database.session.execute(
                database.meta.tables[STATUS].select()
                .where(database.meta.tables[STATUS].c.task_id == 11)
                .order_by(database.meta.tables[STATUS].c.timestamp)
            ).fetchall()
            self.assertEqual([row.task_status_name for row in rows],
                             ["running", "timed_out", "succeeded"])
            self.assertEqual(rows[-1].task_status_name, "succeeded")


if __name__ == "__main__":
    unittest.main()
