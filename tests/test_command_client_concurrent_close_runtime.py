"""Runtime probe for closing CommandClient during an in-flight run."""

import threading
import unittest

import zmq

from parsl.executors.high_throughput.zmq_pipes import CommandClient


class RacySocket:
    def __init__(self):
        self.poll_started = threading.Event()
        self.release_poll = threading.Event()
        self.closed = False

    def poll(self, timeout, flags):
        self.poll_started.set()
        self.release_poll.wait(timeout=2)
        if self.closed:
            raise zmq.error.ZMQError("Socket operation on non-socket")
        return flags

    def send_pyobj(self, message, copy=True):
        if self.closed:
            raise zmq.error.ZMQError("Socket operation on non-socket")

    def close(self):
        self.closed = True


class Context:
    def term(self):
        return None


class CommandClientConcurrentCloseRuntimeTest(unittest.TestCase):
    def test_close_during_run_exposes_raw_socket_error_currently(self):
        socket = RacySocket()
        client = CommandClient.__new__(CommandClient)
        client.zmq_socket = socket
        client.zmq_context = Context()
        client._lock = threading.Lock()
        client.ok = True
        errors = []

        def run_command():
            try:
                client.run("status", timeout_s=1)
            except Exception as error:  # noqa: BLE001 - probe records the raw error
                errors.append(error)

        worker = threading.Thread(target=run_command)
        worker.start()
        self.assertTrue(socket.poll_started.wait(timeout=1))

        # close() does not take _lock in the inspected source, so it can close
        # the socket while run() is inside its poll/send/receive critical path.
        client.close()
        socket.release_poll.set()
        worker.join(timeout=2)

        self.assertFalse(worker.is_alive())
        self.assertEqual(len(errors), 1)
        self.assertIsInstance(errors[0], zmq.error.ZMQError)
        self.assertTrue(client.ok)


if __name__ == "__main__":
    unittest.main()
