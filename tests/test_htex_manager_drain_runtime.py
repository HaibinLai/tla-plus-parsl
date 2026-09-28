"""Runtime probes for HTEX drained-manager bookkeeping."""

import unittest

import zmq

from parsl.executors.high_throughput.interchange import (
    Interchange,
    PKL_DRAINED_CODE,
)


class FakeManagerSocket:
    def __init__(self):
        self.replies = []

    def send_multipart(self, frames):
        self.replies.append(frames)


class HtexManagerDrainRuntimeTest(unittest.TestCase):
    def interchange(self, ready):
        interchange = Interchange.__new__(Interchange)
        interchange._ready_managers = ready
        interchange.manager_sock = FakeManagerSocket()
        interchange._logged_manager_count_token = None
        return interchange

    def test_drained_manager_is_removed_and_acknowledged(self):
        manager_id = b"manager-1"
        interchange = self.interchange({
            manager_id: {"draining": True, "tasks": [], "active": True},
        })
        interesting = {manager_id}

        interchange.expire_drained_managers(interesting, None)

        self.assertNotIn(manager_id, interchange._ready_managers)
        self.assertNotIn(manager_id, interesting)
        self.assertEqual(interchange.manager_sock.replies,
                         [[manager_id, PKL_DRAINED_CODE]])

    def test_stale_interesting_manager_id_currently_raises_key_error(self):
        interchange = self.interchange({})
        with self.assertRaises(KeyError):
            interchange.expire_drained_managers({b"stale"}, None)


if __name__ == "__main__":
    unittest.main()
