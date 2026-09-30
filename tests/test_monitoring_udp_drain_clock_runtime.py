"""Runtime probe for UDP monitoring drain deadlines under wall-clock rollback."""

import socket
import threading
import time
import unittest
from unittest.mock import patch

from parsl.monitoring.radios.udp_router import MonitoringRouter


class ExitEvent:
    def is_set(self):
        return True


class DecreasingClock:
    def __init__(self):
        self.finish = False
        self.calls = 0

    def time(self):
        self.calls += 1
        if self.finish:
            return 1000.0
        # The first value is the drain baseline; subsequent values roll back.
        return 100.0 if self.calls == 1 else 99.0 - self.calls


class MonitoringUDPDrainClockRuntimeTest(unittest.TestCase):
    def test_wall_clock_rollback_keeps_current_router_draining(self):
        router = MonitoringRouter.__new__(MonitoringRouter)
        router.exit_event = ExitEvent()
        router.atexit_timeout = 0.05
        clock = DecreasingClock()

        def timeout_message():
            time.sleep(0.005)
            raise socket.timeout()

        router.process_message = timeout_message
        worker = threading.Thread(target=router.start)
        with patch("parsl.monitoring.radios.udp_router.time.time", side_effect=clock.time):
            worker.start()
            time.sleep(0.12)
            self.assertTrue(worker.is_alive())
            clock.finish = True
            worker.join(timeout=1)

        self.assertFalse(worker.is_alive())


if __name__ == "__main__":
    unittest.main()
