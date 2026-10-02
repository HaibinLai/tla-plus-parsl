"""Runtime bridge for provider loss, retry attempts, and monitoring persistence."""

import datetime
import tempfile
import unittest
from concurrent.futures import Future

from parsl.monitoring.db_manager import Database, STATUS, WORKFLOW


class ProviderExecutorTimedMonitoringRuntimeTest(unittest.TestCase):
    def test_old_attempt_is_stale_while_current_retry_persists_terminal_status(self):
        attempt_futures = [Future(), Future()]
        current_attempt = 0
        provider_active = True

        with tempfile.TemporaryDirectory() as directory:
            database = Database(f"sqlite:///{directory}/monitoring.db")
            now = datetime.datetime.now()
            database.insert(table=WORKFLOW, messages=[{
                "run_id": "timed-run", "time_began": now, "host": "host",
                "user": "user", "rundir": directory,
                "tasks_failed_count": 0, "tasks_completed_count": 0,
            }])
            database.insert(table=STATUS, messages=[{
                "task_id": 3, "run_id": "timed-run",
                "task_status_name": "running", "timestamp": now, "try_id": 0,
            }])

            provider_active = False
            current_attempt = 1
            database.insert(table=STATUS, messages=[{
                "task_id": 3, "run_id": "timed-run",
                "task_status_name": "retry_wait",
                "timestamp": now + datetime.timedelta(seconds=1), "try_id": 0,
            }])

            def deliver(attempt, value):
                if attempt != current_attempt:
                    return False
                attempt_futures[attempt].set_result(value)
                return True

            self.assertFalse(deliver(0, "late-old"))
            self.assertFalse(attempt_futures[0].done())

            provider_active = True
            self.assertTrue(provider_active)
            database.insert(table=STATUS, messages=[{
                "task_id": 3, "run_id": "timed-run", "task_status_name": "done",
                "timestamp": now + datetime.timedelta(seconds=2), "try_id": 1,
            }])
            self.assertTrue(deliver(1, "current"))
            self.assertEqual(attempt_futures[1].result(), "current")

            rows = database.session.execute(database.meta.tables[STATUS].select()).fetchall()
            current = max(
                (row for row in rows if row.task_id == 3 and row.run_id == "timed-run"),
                key=lambda row: row.try_id,
            )
            self.assertEqual(current.try_id, 1)
            self.assertEqual(current.task_status_name, "done")


if __name__ == "__main__":
    unittest.main()
