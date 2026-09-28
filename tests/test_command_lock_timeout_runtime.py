"""Runtime probe for CommandClient timeout while waiting on its Python lock."""

import threading
import time
import unittest

import zmq

from parsl.executors.high_throughput.zmq_pipes import CommandClient


class ReadySocket:
    def __init__(self):
        self.messages = []

    def poll(self, timeout, flags):
        return flags

    def send_pyobj(self, message, copy=True):
        self.messages.append(message)

    def recv_pyobj(self):
        return "reply"


class CommandLockTimeoutRuntimeTest(unittest.TestCase):
    def test_lock_wait_can_exceed_command_deadline_before_send(self):
        client = CommandClient.__new__(CommandClient)
        client.ok = True
        client._lock = threading.Lock()
        client.zmq_socket = ReadySocket()
        started = threading.Event()
        finished = threading.Event()
        outcome = []

        def invoke():
            started.set()
            try:
                outcome.append(client.run("command", timeout_s=0.01))
            finally:
                finished.set()

        client._lock.acquire()
        worker = threading.Thread(target=invoke)
        worker.start()
        self.assertTrue(started.wait(timeout=1))
        self.assertFalse(finished.wait(timeout=0.05))

        client._lock.release()
        self.assertTrue(finished.wait(timeout=1))
        worker.join(timeout=1)

        self.assertEqual(outcome, ["reply"])
        self.assertEqual(client.zmq_socket.messages, ["command"])


if __name__ == "__main__":
    unittest.main()
