"""Runtime probe for the ZMQ router's wall-clock receive-batch deadline."""

import threading
import unittest
from unittest.mock import patch

from parsl.monitoring.radios.zmq_router import MonitoringRouter


class TimeoutReceiver:
    def __init__(self, exit_event):
        self.calls = 0
        self.exit_event = exit_event

    def recv_pyobj(self):
        self.calls += 1
        if self.calls >= 3:
            # Stop the outer listener after the delayed inner batch has
            # observed the deadline.
            self.exit_event.set()
        return ("TASK_INFO", {"task_id": self.calls})


class Sink:
    def send(self, _message):
        pass


class MonitoringZMQBatchClockRuntimeTest(unittest.TestCase):
    def test_wall_clock_rollback_extends_inner_receive_batch_currently(self):
        exit_event = threading.Event()
        receiver = TimeoutReceiver(exit_event)
        router = MonitoringRouter.__new__(MonitoringRouter)
        router.exit_event = exit_event
        router.zmq_receiver_channel = receiver
        router.target_radio = Sink()

        # start=100; the inner loop then sees 99 repeatedly, so it receives
        # several timeout cycles before the clock finally reaches the deadline.
        # A monotonic clock would reach 101 on the first cycle and finish the
        # one-second batch after one receive attempt.
        clock_values = iter([100, 99, 99, 99, 101])
        with patch("parsl.monitoring.radios.zmq_router.time.time", side_effect=clock_values), \
             patch("parsl.monitoring.radios.zmq_router.logger.warning"):
            thread = threading.Thread(target=router.start, daemon=True)
            thread.start()
            thread.join(timeout=1)

        self.assertFalse(thread.is_alive())
        self.assertGreater(receiver.calls, 1)
        exit_event.set()


if __name__ == "__main__":
    unittest.main()
