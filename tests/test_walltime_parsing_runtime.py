"""Runtime probe for provider walltime minute conversion."""

import unittest

from parsl.utils import wtime_to_minutes


class WalltimeParsingRuntimeTest(unittest.TestCase):
    def test_subminute_walltime_is_truncated_to_zero_minutes_currently(self):
        self.assertEqual(wtime_to_minutes("00:00:59"), 0)


if __name__ == "__main__":
    unittest.main()
