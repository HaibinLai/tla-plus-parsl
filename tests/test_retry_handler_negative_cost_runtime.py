"""Runtime probe for negative retry-handler costs bypassing the retry budget."""

import unittest

import parsl
from parsl import Config, python_app
from parsl.executors.threads import ThreadPoolExecutor


attempts = {"count": 0}
handler_calls = {"count": 0}


@python_app
def always_fail_with_negative_cost_probe():
    attempts["count"] += 1
    raise ValueError("execution failure")


def negative_cost_then_stop(exception, task_record):
    handler_calls["count"] += 1
    if handler_calls["count"] <= 3:
        return -1
    raise RuntimeError("probe stop after repeated negative retry costs")


class RetryHandlerNegativeCostRuntimeTest(unittest.TestCase):
    def test_negative_cost_retries_past_zero_budget_currently(self):
        attempts["count"] = 0
        handler_calls["count"] = 0
        config = Config(
            executors=[ThreadPoolExecutor(max_threads=1)],
            retries=0,
            retry_handler=negative_cost_then_stop,
        )

        with parsl.load(config):
            future = always_fail_with_negative_cost_probe()
            error = future.exception()

        self.assertIsInstance(error, RuntimeError)
        self.assertEqual(attempts["count"], 4)
        self.assertEqual(handler_calls["count"], 4)


if __name__ == "__main__":
    unittest.main()
