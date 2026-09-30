"""Runtime bridge for serialized task payloads and TasksOutgoing closure."""

import unittest

from parsl.executors.high_throughput.zmq_pipes import TasksOutgoing
from parsl.serialize import pack_apply_message


class ClosedSocket:
    def __init__(self):
        self.closed = False
        self.sent = []

    def send_pyobj(self, message):
        if self.closed:
            raise RuntimeError("send on closed socket")
        self.sent.append(message)

    def close(self):
        self.closed = True


class Context:
    def term(self):
        return None


class TaskTransportCloseRuntimeTest(unittest.TestCase):
    def test_serialized_task_reaches_sender_but_close_blocks_later_send_currently(self):
        sender = TasksOutgoing.__new__(TasksOutgoing)
        sender.zmq_socket = ClosedSocket()
        sender.zmq_context = Context()

        payload = pack_apply_message(lambda value: value + 1, (1,), {})
        sender.put({"task_id": 1, "payload": payload})
        self.assertEqual(len(sender.zmq_socket.sent), 1)

        sender.close()
        with self.assertRaisesRegex(RuntimeError, "closed socket"):
            sender.put({"task_id": 2, "payload": payload})


if __name__ == "__main__":
    unittest.main()
