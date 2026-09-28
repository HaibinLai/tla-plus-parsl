"""Runtime probes for HTEX TasksOutgoing send/close semantics."""

import unittest

from parsl.executors.high_throughput.zmq_pipes import TasksOutgoing


class FakeSocket:
    def __init__(self):
        self.sent = []
        self.closed = False

    def send_pyobj(self, message):
        self.sent.append(message)

    def close(self):
        self.closed = True


class FakeContext:
    def __init__(self):
        self.terminated = False

    def term(self):
        self.terminated = True


class TasksOutgoingRuntimeTest(unittest.TestCase):
    def sender_with(self):
        sender = TasksOutgoing.__new__(TasksOutgoing)
        sender.zmq_socket = FakeSocket()
        sender.zmq_context = FakeContext()
        return sender

    def test_put_sends_python_object_without_reply_handshake(self):
        sender = self.sender_with()
        message = {"task_id": 4, "payload": b"wire"}

        sender.put(message)

        self.assertEqual(sender.zmq_socket.sent, [message])

    def test_close_closes_socket_and_context(self):
        sender = self.sender_with()

        sender.close()

        self.assertTrue(sender.zmq_socket.closed)
        self.assertTrue(sender.zmq_context.terminated)


if __name__ == "__main__":
    unittest.main()
