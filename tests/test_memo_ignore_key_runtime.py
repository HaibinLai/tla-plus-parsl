"""Runtime probe for unknown memoization ignore-list names."""

import unittest

import parsl
from parsl import python_app
from parsl.config import Config
from parsl.executors.threads import ThreadPoolExecutor


class MemoIgnoreKeyRuntimeTest(unittest.TestCase):
    def test_unknown_ignore_key_currently_exposes_key_error(self):
        @python_app(cache=True, ignore_for_cache=["not_an_argument"])
        def app(value):
            return value

        with parsl.load(Config(executors=[ThreadPoolExecutor(max_threads=1)])):
            future = app(1)
            with self.assertRaises(KeyError):
                future.result()


if __name__ == "__main__":
    unittest.main()
