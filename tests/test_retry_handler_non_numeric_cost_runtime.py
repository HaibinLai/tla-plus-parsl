"""Runtime probe for non-numeric retry-handler results leaving a Future pending."""

import unittest
from concurrent.futures import TimeoutError

import parsl
from parsl import Config, python_app
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def fail_with_non_numeric_cost_probe():
    raise ValueError("execution failure")


def non_numeric_cost(exception, task_record):
    return "not-a-number"


class RetryHandlerNonNumericCostRuntimeTest(unittest.TestCase):
    def test_non_numeric_cost_leaves_outer_future_pending_currently(self):
        config = Config(
            executors=[ThreadPoolExecutor(max_threads=1)],
            retries=0,
            retry_handler=non_numeric_cost,
        )

        with parsl.load(config):
            future = fail_with_non_numeric_cost_probe()
            with self.assertRaises(TimeoutError):
                future.result(timeout=1)


if __name__ == "__main__":
    unittest.main()
