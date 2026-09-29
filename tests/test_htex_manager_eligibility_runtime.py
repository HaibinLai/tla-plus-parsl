"""Runtime probe for HTEX dispatch filtering of inactive/draining managers."""

import unittest
from types import SimpleNamespace

from parsl.executors.high_throughput.interchange import Interchange


class FixedSelector:
    def sort_managers(self, ready_managers, manager_list):
        return [b"m0", b"m1", b"m2"]


class RecordingSocket:
    def __init__(self):
        self.messages = []

    def send_multipart(self, message):
        self.messages.append(message)


class HtexManagerEligibilityRuntimeTest(unittest.TestCase):
    def test_dispatch_skips_inactive_and_draining_managers(self):
        interchange = Interchange.__new__(Interchange)
        interchange.manager_selector = FixedSelector()
        interchange._ready_managers = {
            b"m0": {"active": False, "draining": False, "max_capacity": 1, "tasks": []},
            b"m1": {"active": True, "draining": True, "max_capacity": 1, "tasks": []},
            b"m2": {"active": True, "draining": False, "max_capacity": 1, "tasks": []},
        }
        interchange.pending_task_queue = ["queued-task"]
        interchange.manager_sock = RecordingSocket()
        interchange.count = 0
        interchange.get_tasks = lambda capacity: [{"task_id": "t1"}]
        interchange._send_monitoring_info = lambda radio, manager: None

        interesting = set(interchange._ready_managers)
        interchange.process_tasks_to_send(interesting, monitoring_radio=None)

        self.assertEqual([message[0] for message in interchange.manager_sock.messages], [b"m2"])
        self.assertEqual(interchange._ready_managers[b"m0"]["tasks"], [])
        self.assertEqual(interchange._ready_managers[b"m1"]["tasks"], [])
        self.assertEqual(interchange._ready_managers[b"m2"]["tasks"], ["t1"])


if __name__ == "__main__":
    unittest.main()
