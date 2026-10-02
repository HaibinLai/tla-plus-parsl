"""Runtime bridge for list-valued join output Futures and monitoring persistence."""

import datetime
import tempfile
import unittest
from concurrent.futures import Future
from types import SimpleNamespace

import parsl
from parsl import Config, join_app, python_app
from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.files import File
from parsl.executors.threads import ThreadPoolExecutor
from parsl.monitoring.db_manager import Database, STATUS, WORKFLOW


@python_app
def multi_output_inner(value):
    return value


@join_app
def multi_output_join():
    return [multi_output_inner("left"), multi_output_inner("right")]


class OutputStage:
    def __init__(self):
        self.parents = []

    def can_stage_out(self, file):
        return True

    def stage_out(self, manager, executor, file, parent):
        transfer = Future()
        self.parents.append((file, parent, transfer))
        parent.add_done_callback(lambda _: transfer.set_result("published"))
        return transfer


class JoinMultiOutputMonitoringRuntimeTest(unittest.TestCase):
    def test_all_join_outputs_publish_before_terminal_monitoring(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=3)])
        with parsl.load(config):
            outer = multi_output_join()
            self.assertEqual(outer.result(), ["left", "right"])

        stage = OutputStage()
        manager = DataManager(SimpleNamespace(executors={
            "exec": SimpleNamespace(storage_access=[stage]),
        }))
        transfers = [manager.stage_out(File(f"file:///tmp/output-{i}"), "exec", outer)
                     for i in (1, 2)]
        self.assertTrue(all(transfer.done() for transfer in transfers))
        self.assertEqual([parent for _, parent, _ in stage.parents], [outer, outer])

        with tempfile.TemporaryDirectory() as directory:
            database = Database("sqlite:///" + directory + "/monitoring.db")
            now = datetime.datetime.now()
            database.insert(table=WORKFLOW, messages=[{
                "run_id": "join-output-run", "time_began": now, "host": "host",
                "user": "user", "rundir": directory,
                "tasks_failed_count": 0, "tasks_completed_count": 1,
            }])
            database.insert(table=STATUS, messages=[{
                "task_id": outer.task_record["id"], "run_id": "join-output-run",
                "task_status_name": "done", "timestamp": now, "try_id": 0,
            }])
            rows = database.session.execute(
                database.meta.tables[STATUS].select()
            ).fetchall()

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].task_status_name, "done")


if __name__ == "__main__":
    unittest.main()
