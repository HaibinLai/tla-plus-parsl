"""Runtime probes for HTEX worker-pool control-frame decoding boundaries."""

import pickle
import unittest

from parsl.executors.high_throughput.process_worker_pool import Manager


class _Socket:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class WorkerPoolControlFrameRuntimeTest(unittest.TestCase):
    def test_control_frames_are_distinct_pickled_records(self):
        heartbeat_socket = _Socket()
        drain_socket = _Socket()

        Manager.heartbeat_to_incoming(heartbeat_socket)
        Manager.drain_to_incoming(drain_socket)

        self.assertEqual(pickle.loads(heartbeat_socket.messages[0]), {"type": "heartbeat"})
        self.assertEqual(pickle.loads(drain_socket.messages[0]), {"type": "drain"})
        self.assertNotEqual(heartbeat_socket.messages[0], drain_socket.messages[0])

    def test_malformed_frame_is_not_a_decodable_control_record(self):
        with self.assertRaises((pickle.UnpicklingError, EOFError, ValueError, AttributeError)):
            pickle.loads(b"not-a-pickle-control-frame")


if __name__ == "__main__":
    unittest.main()
