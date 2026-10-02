"""Runtime bridge for HTEX task-dispatch send ownership."""

import unittest

from parsl.executors.high_throughput.interchange import Interchange


class Selector:
    def sort_managers(self, ready_managers, manager_ids):
        return [b"manager-1"]


class FailingSocket:
    def send_multipart(self, _message):
        raise OSError("simulated ZMQ send failure")


class HtexTaskDispatchSendFailureRuntimeTest(unittest.TestCase):
    def test_send_failure_loses_task_after_pending_queue_pop_currently(self):
        interchange = Interchange.__new__(Interchange)
        interchange.manager_selector = Selector()
        interchange._ready_managers = {
            b"manager-1": {
                "active": True,
                "draining": False,
                "max_capacity": 1,
                "tasks": [],
            }
        }
        pending = ["task-1"]
        interchange.pending_task_queue = pending
        interchange.manager_sock = FailingSocket()
        interchange.count = 0
        interchange._send_monitoring_info = lambda _radio, _manager: None

        def get_tasks(_capacity):
            return [{"task_id": "task-1"}] if pending.pop() else []

        interchange.get_tasks = get_tasks

        with self.assertRaises(OSError):
            interchange.process_tasks_to_send({b"manager-1"}, monitoring_radio=None)

        self.assertEqual(pending, [])
        self.assertEqual(interchange._ready_managers[b"manager-1"]["tasks"], [])


if __name__ == "__main__":
    unittest.main()
