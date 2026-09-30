"""Runtime probe for cleanup returning while an outer join is still pending."""

import time
import unittest
from concurrent.futures import Future

import parsl
from parsl import Config, join_app
from parsl.dataflow.states import States
from parsl.executors.threads import ThreadPoolExecutor


pending_inner = Future()


@join_app
def join_after_cleanup():
    return pending_inner


class JoinCleanupLifecycleRuntimeTest(unittest.TestCase):
    def test_cleanup_returns_before_late_join_callback_currently(self):
        global pending_inner
        pending_inner = Future()
        dfk = parsl.load(Config(executors=[ThreadPoolExecutor(max_threads=1)]))
        try:
            outer = join_after_cleanup()

            deadline = time.monotonic() + 2
            while (not dfk.tasks or
                   not any(record["status"] == States.joining
                           for record in dfk.tasks.values())) and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue(any(record["status"] == States.joining
                                for record in dfk.tasks.values()))

            dfk.cleanup()
            self.assertFalse(outer.done())

            pending_inner.set_result("late-result")
            self.assertEqual(outer.result(timeout=2), "late-result")
        finally:
            if not dfk.cleanup_called:
                dfk.cleanup()


if __name__ == "__main__":
    unittest.main()
