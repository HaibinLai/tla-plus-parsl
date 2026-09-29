"""Runtime bridge for HTEX shutdown terminate/wait/kill ordering."""

import subprocess
import threading
import unittest
from unittest.mock import patch

from parsl.executors.high_throughput.executor import HighThroughputExecutor


class ProcessDouble:
    def __init__(self):
        self.calls = []

    def terminate(self):
        self.calls.append("terminate")

    def wait(self, timeout=None):
        self.calls.append(("wait", timeout))
        raise subprocess.TimeoutExpired(cmd="interchange", timeout=timeout)

    def kill(self):
        self.calls.append("kill")


class CloseDouble:
    def __init__(self):
        self.closed = 0

    def close(self):
        self.closed += 1


class HtexShutdownTimeoutRuntimeTest(unittest.TestCase):
    def test_timeout_kills_before_closing_pipes(self):
        process = ProcessDouble()
        outgoing = CloseDouble()
        command = CloseDouble()
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor.interchange_proc = process
        executor._result_queue_thread_exit = threading.Event()
        executor._result_queue_thread = None
        executor.outgoing_q = outgoing
        executor.command_client = command
        executor.zmq_monitoring = None
        executor.monitoring_receiver = None

        with patch("parsl.executors.high_throughput.executor.logger"):
            executor.shutdown(timeout=0.01)

        self.assertEqual(process.calls[0], "terminate")
        self.assertEqual(process.calls[1], ("wait", 0.01))
        self.assertEqual(process.calls[2], "kill")
        self.assertEqual(outgoing.closed, 1)
        self.assertEqual(command.closed, 1)


if __name__ == "__main__":
    unittest.main()
