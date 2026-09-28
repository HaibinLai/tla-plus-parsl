"""Runtime probes for physical retries and Python app walltime enforcement."""

import time
import unittest

import parsl
from parsl import Config, python_app
from parsl.app.errors import AppTimeout
from parsl.executors.threads import ThreadPoolExecutor


attempt_counter = {"count": 0}


@python_app
def fail_once_then_succeed():
    attempt_counter["count"] += 1
    if attempt_counter["count"] == 1:
        raise ValueError("first physical attempt")
    return attempt_counter["count"]


@python_app
def slow_app(walltime=None):
    time.sleep(0.2)
    return "finished"


@python_app
def catches_timeout(walltime=None):
    try:
        time.sleep(0.2)
    except AppTimeout:
        return "caught-timeout"
    return "finished"


class RetryTimeoutRuntimeTest(unittest.TestCase):
    def test_retry_uses_a_new_physical_attempt(self):
        attempt_counter["count"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=1)], retries=1)

        with parsl.load(config):
            future = fail_once_then_succeed()
            self.assertEqual(future.result(), 2)

        self.assertEqual(attempt_counter["count"], 2)

    def test_walltime_timeout_rejects_the_future(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=1)], retries=0)

        with parsl.load(config):
            future = slow_app(walltime=0.01)
            self.assertIsInstance(future.exception(), AppTimeout)

    def test_user_function_can_catch_injected_timeout_currently(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=1)], retries=0)

        with parsl.load(config):
            future = catches_timeout(walltime=0.01)
            self.assertEqual(future.result(), "caught-timeout")


if __name__ == "__main__":
    unittest.main()
