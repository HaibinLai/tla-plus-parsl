"""Runtime bridge for duplicate join positions preserving result identity."""

import unittest

from parsl import join_app, load, python_app
from parsl.config import Config
from parsl.executors.threads import ThreadPoolExecutor


class JoinDuplicateObjectIdentityRuntimeTest(unittest.TestCase):
    def test_duplicate_future_positions_share_the_same_python_result_object(self):
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)], strategy=None)

        @python_app
        def make_value():
            return {"values": [1]}

        @join_app
        def duplicate(values):
            return values

        with load(config):
            inner = make_value()
            outer = duplicate([inner, inner])
            result = outer.result()

        self.assertEqual(result[0], result[1])
        self.assertIs(result[0], result[1])


if __name__ == "__main__":
    unittest.main()
