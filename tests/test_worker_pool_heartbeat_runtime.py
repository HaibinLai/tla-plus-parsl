"""Runtime probes for HTEX worker heartbeat/drain message encoding."""

import pickle
import unittest

from parsl.executors.high_throughput.process_worker_pool import Manager


class FakeSocket:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class WorkerPoolHeartbeatRuntimeTest(unittest.TestCase):
    def test_heartbeat_message_is_pickled_with_expected_type(self):
        socket = FakeSocket()

        Manager.heartbeat_to_incoming(socket)

        self.assertEqual(pickle.loads(socket.messages[0]), {"type": "heartbeat"})

    def test_drain_message_is_pickled_with_expected_type(self):
        socket = FakeSocket()

        Manager.drain_to_incoming(socket)

        self.assertEqual(pickle.loads(socket.messages[0]), {"type": "drain"})


if __name__ == "__main__":
    unittest.main()
