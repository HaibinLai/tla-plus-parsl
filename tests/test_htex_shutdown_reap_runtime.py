"""Runtime probe for HTEX shutdown kill-without-reap behavior."""

import subprocess
import threading
import unittest
from unittest.mock import patch

from parsl.executors.high_throughput.executor import HighThroughputExecutor


class PersistentKillProcess:
    def __init__(self):
        self.alive = True
        self.calls = []

    def terminate(self):
        self.calls.append("terminate")

    def wait(self, timeout=None):
        self.calls.append(("wait", timeout))
        raise subprocess.TimeoutExpired(cmd="interchange", timeout=timeout)

    def kill(self):
        self.calls.append("kill")
        # Model an asynchronous kill whose exit still needs wait()/reap.


class CloseDouble:
    def __init__(self):
        self.closed = 0

    def close(self):
        self.closed += 1


class HtexShutdownReapRuntimeTest(unittest.TestCase):
    def test_shutdown_returns_after_kill_without_reaping_currently(self):
        process = PersistentKillProcess()
        executor = HighThroughputExecutor.__new__(HighThroughputExecutor)
        executor.interchange_proc = process
        executor._result_queue_thread_exit = threading.Event()
        executor._result_queue_thread = None
        executor.outgoing_q = CloseDouble()
        executor.command_client = CloseDouble()
        executor.zmq_monitoring = None
        executor.monitoring_receiver = None

        with patch("parsl.executors.high_throughput.executor.logger"):
            executor.shutdown(timeout=0.01)

        self.assertIn("kill", process.calls)
        self.assertTrue(process.alive)
        self.assertEqual(executor.outgoing_q.closed, 1)
        self.assertEqual(executor.command_client.closed, 1)


if __name__ == "__main__":
    unittest.main()
