"""Runtime probe for malformed provider scale-in response shape."""

import unittest

from parsl.executors.status_handling import BlockProviderExecutor


class ScaleInResultShapeRuntimeTest(unittest.TestCase):
    def test_partial_cancel_result_exposes_raw_assertion_currently(self):
        with self.assertRaises(AssertionError):
            BlockProviderExecutor._filter_scale_in_ids(
                object(), ["job-1", "job-2"], [True]
            )


if __name__ == "__main__":
    unittest.main()
