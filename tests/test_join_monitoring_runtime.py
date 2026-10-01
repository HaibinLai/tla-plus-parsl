"""Runtime bridge for join_app retry generations and SQLite monitoring rows."""

import datetime
import tempfile
import unittest

import parsl
from parsl import Config, join_app, python_app
from parsl.executors.threads import ThreadPoolExecutor
from parsl.monitoring.db_manager import Database, STATUS, WORKFLOW


attempts = {"count": 0}
inner_refs = []


@python_app
def flaky_inner():
    attempts["count"] += 1
    if attempts["count"] == 1:
        raise RuntimeError("first inner attempt")
    return "inner-success"


@join_app
def joined_flaky_inner():
    future = flaky_inner()
    inner_refs.append(future)
    return future


class JoinMonitoringRuntimeTest(unittest.TestCase):
    def test_real_join_retry_can_be_followed_by_old_try_status_currently(self):
        attempts["count"] = 0
        inner_refs.clear()
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)], retries=1)
        with parsl.load(config):
            outer = joined_flaky_inner()
            self.assertEqual(outer.result(), "inner-success")

        self.assertEqual(attempts["count"], 2)
        self.assertEqual(len(inner_refs), 1)
        inner = inner_refs[0]
        self.assertEqual(inner.task_record["try_id"], 1)

        with tempfile.TemporaryDirectory() as directory:
            database = Database("sqlite:///" + directory + "/monitoring.db")
            base = datetime.datetime.now()
            database.insert(table=WORKFLOW, messages=[{
                "run_id": "join-monitoring",
                "time_began": base,
                "host": "host",
                "user": "user",
                "rundir": directory,
                "tasks_failed_count": 0,
                "tasks_completed_count": 0,
            }])

            events = [
                (base + datetime.timedelta(seconds=1), 0, "failed"),
                (base + datetime.timedelta(seconds=2), 1, "succeeded"),
                # A delayed old-generation event is still accepted by the
                # current append-only STATUS table.
                (base + datetime.timedelta(seconds=3), 0, "succeeded"),
            ]
            for timestamp, try_id, status in events:
                database.insert(table=STATUS, messages=[{
                    "task_id": inner.tid,
                    "run_id": "join-monitoring",
                    "task_status_name": status,
                    "timestamp": timestamp,
                    "try_id": try_id,
                }])

            rows = database.session.execute(
                database.meta.tables[STATUS].select()
                .where(database.meta.tables[STATUS].c.task_id == inner.tid)
                .order_by(database.meta.tables[STATUS].c.timestamp)
            ).fetchall()

        self.assertEqual([row.try_id for row in rows], [0, 1, 0])
        self.assertEqual(rows[-1].try_id, 0)


if __name__ == "__main__":
    unittest.main()
