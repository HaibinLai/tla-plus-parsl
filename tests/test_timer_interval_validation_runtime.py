"""Runtime probe for Timer negative-interval normalization."""

import unittest

from parsl.utils import Timer


class TimerIntervalValidationRuntimeTest(unittest.TestCase):
    def test_negative_interval_is_silently_clamped_to_zero_currently(self):
        timer = Timer(lambda: None, interval=-1, name="runtime-negative-interval")
        try:
            self.assertEqual(timer.interval, 0)
        finally:
            timer.close(timeout=1.0)


if __name__ == "__main__":
    unittest.main()
