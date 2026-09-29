"""Runtime probe for persistent receive failures in the monitoring ZMQ router."""

import threading
import time
import unittest
from unittest.mock import patch

from parsl.monitoring.radios.zmq_router import MonitoringRouter


class BrokenReceiver:
    def __init__(self):
        self.calls = 0

    def recv_pyobj(self):
        self.calls += 1
        raise RuntimeError("persistent receive failure")


class MonitoringZMQRouterFailureRuntimeTest(unittest.TestCase):
    def test_persistent_receive_failure_retries_until_external_stop_currently(self):
        exit_event = threading.Event()
        receiver = BrokenReceiver()
        router = MonitoringRouter.__new__(MonitoringRouter)
        router.exit_event = exit_event
        router.zmq_receiver_channel = receiver

        finished = threading.Event()

        def run_router():
            try:
                router.start()
            finally:
                finished.set()

        with patch("parsl.monitoring.radios.zmq_router.logger.warning"):
            thread = threading.Thread(target=run_router, daemon=True)
            thread.start()
            time.sleep(0.03)
            self.assertFalse(finished.is_set())
            self.assertGreater(receiver.calls, 0)
            exit_event.set()
            thread.join(timeout=1)

        self.assertTrue(finished.is_set())


if __name__ == "__main__":
    unittest.main()
