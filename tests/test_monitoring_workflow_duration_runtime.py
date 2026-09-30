"""Runtime probe for workflow duration being silently dropped by SQLite schema."""

import datetime
import tempfile
import unittest

import sqlalchemy as sa

from parsl.monitoring.db_manager import Database, WORKFLOW


class MonitoringWorkflowDurationRuntimeTest(unittest.TestCase):
    def test_bulk_update_silently_ignores_missing_workflow_duration_column(self):
        with tempfile.TemporaryDirectory() as directory:
            database = Database(f"sqlite:///{directory}/monitoring.db")
            database.insert(table=WORKFLOW, messages=[{
                "run_id": "run-1",
                "time_began": datetime.datetime.now(),
                "host": "host",
                "user": "user",
                "rundir": directory,
                "tasks_failed_count": 0,
                "tasks_completed_count": 0,
            }])
            database.update(
                table=WORKFLOW,
                columns=["run_id", "time_completed", "workflow_duration"],
                messages=[{
                    "run_id": "run-1",
                    "time_completed": datetime.datetime.now(),
                    "workflow_duration": 12.5,
                }],
            )

            columns = {
                row[1]
                for row in database.eng.connect().execute(sa.text("PRAGMA table_info(workflow)"))
            }
            self.assertNotIn("workflow_duration", columns)
            self.assertIsNone(database.meta.tables[WORKFLOW].c.get("workflow_duration"))


if __name__ == "__main__":
    unittest.main()
