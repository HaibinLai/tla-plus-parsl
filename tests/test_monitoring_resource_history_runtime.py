"""Runtime probe for out-of-order and duplicate RESOURCE samples."""

import datetime
import tempfile
import unittest

from parsl.monitoring.db_manager import Database, RESOURCE, WORKFLOW


class MonitoringResourceHistoryRuntimeTest(unittest.TestCase):
    def test_samples_are_append_only_and_latest_is_timestamp_ordered(self):
        database = Database("sqlite:///" + tempfile.mktemp(suffix=".db"))
        base = datetime.datetime.now()
        database.insert(
            table=WORKFLOW,
            messages=[{
                "run_id": "run-1",
                "time_began": base,
                "host": "host",
                "user": "user",
                "rundir": "/tmp/run",
                "tasks_failed_count": 0,
                "tasks_completed_count": 0,
            }],
        )

        messages = [
            {"try_id": 0, "task_id": 4, "run_id": "run-1",
             "timestamp": base + datetime.timedelta(seconds=2),
             "psutil_process_memory_percent": 30.0},
            {"try_id": 0, "task_id": 4, "run_id": "run-1",
             "timestamp": base,
             "psutil_process_memory_percent": 10.0},
            {"try_id": 0, "task_id": 4, "run_id": "run-1",
             "timestamp": base + datetime.timedelta(seconds=1),
             "psutil_process_memory_percent": 20.0},
        ]
        for message in (messages[0], messages[1], messages[2]):
            database.insert(table=RESOURCE, messages=[message])

        with self.assertRaises(Exception):
            database.insert(table=RESOURCE, messages=[messages[0]])
        database.rollback()

        rows = database.session.execute(database.meta.tables[RESOURCE].select()).fetchall()
        self.assertEqual(len(rows), 3)
        latest = max(rows, key=lambda row: row.timestamp)
        self.assertEqual(latest.psutil_process_memory_percent, 30.0)


if __name__ == "__main__":
    unittest.main()
