"""Runtime probe for TasksOutgoing.put after close."""

import unittest

from parsl.executors.high_throughput.zmq_pipes import TasksOutgoing


class ClosedSocket:
    def __init__(self):
        self.closed = False

    def send_pyobj(self, message):
        if self.closed:
            raise RuntimeError("send on closed socket")

    def close(self):
        self.closed = True


class Context:
    def term(self):
        pass


class TasksOutgoingCloseRuntimeTest(unittest.TestCase):
    def test_put_after_close_reaches_closed_socket_currently(self):
        sender = TasksOutgoing.__new__(TasksOutgoing)
        sender.zmq_socket = ClosedSocket()
        sender.zmq_context = Context()
        sender.close()

        with self.assertRaisesRegex(RuntimeError, "closed socket"):
            sender.put({"task_id": 1})


if __name__ == "__main__":
    unittest.main()
