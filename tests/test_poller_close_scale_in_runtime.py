"""Runtime probe for JobStatusPoller close/scale-in ordering."""

import threading
import unittest

from parsl.jobs.job_status_poller import JobStatusPoller


class LiveThread:
    def __init__(self):
        self.alive = True
        self.join_called = False

    def join(self, timeout=None):
        self.join_called = True
        # Model a callback that outlives Timer.close(timeout).
        return None


class PollerCloseScaleInRuntimeTest(unittest.TestCase):
    def test_current_close_scales_in_while_timer_thread_is_alive(self):
        poller = JobStatusPoller.__new__(JobStatusPoller)
        poller._kill_event = threading.Event()
        poller._thread = LiveThread()
        poller._executors = []

        observed = {}

        class Executor:
            label = "fake"
            bad_state_is_set = False
            status_facade = {"block": object()}

            def scale_in_facade(self, count):
                observed["alive_during_scale_in"] = poller._thread.alive
                observed["count"] = count

        poller._executors.append(Executor())
        poller.close(timeout=0)

        self.assertTrue(poller._thread.join_called)
        self.assertTrue(observed["alive_during_scale_in"])
        self.assertEqual(observed["count"], 1)


if __name__ == "__main__":
    unittest.main()
