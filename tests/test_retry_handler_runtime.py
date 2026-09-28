"""Runtime probe for retry_handler failure-cost accounting."""

import unittest

import parsl
from parsl import Config, python_app
from parsl.executors.threads import ThreadPoolExecutor


attempts = {"count": 0}
handler_calls = {"count": 0}


@python_app
def always_fail_for_retry_handler():
    attempts["count"] += 1
    raise ValueError("execution failure")


def zero_cost_then_fail(exception, task_record):
    handler_calls["count"] += 1
    if handler_calls["count"] == 1:
        return 0
    raise RuntimeError("retry handler failure")


class RetryHandlerRuntimeTest(unittest.TestCase):
    def test_zero_cost_handler_bypasses_zero_retry_budget_currently(self):
        attempts["count"] = 0
        handler_calls["count"] = 0
        config = Config(
            executors=[ThreadPoolExecutor(max_threads=1)],
            retries=0,
            retry_handler=zero_cost_then_fail,
        )

        with parsl.load(config):
            future = always_fail_for_retry_handler()
            error = future.exception()

        self.assertIsInstance(error, RuntimeError)
        self.assertEqual(attempts["count"], 2)
        self.assertEqual(handler_calls["count"], 2)


if __name__ == "__main__":
    unittest.main()
