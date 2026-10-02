"""Runtime bridge for AppFuture projection across a physical retry."""

import unittest

import parsl
from parsl import Config, python_app
from parsl.executors.threads import ThreadPoolExecutor


attempts = {"count": 0}


@python_app
def retrying_projection_source():
    attempts["count"] += 1
    if attempts["count"] == 1:
        raise RuntimeError("first physical attempt")
    return {"value": 42}


class FutureProjectionRetryRuntimeTest(unittest.TestCase):
    def test_projection_waits_for_logical_retry_result(self):
        attempts["count"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)], retries=1)
        with parsl.load(config):
            source = retrying_projection_source()
            projected = source["value"]
            self.assertEqual(projected.result(), 42)

        self.assertEqual(attempts["count"], 2)


if __name__ == "__main__":
    unittest.main()
