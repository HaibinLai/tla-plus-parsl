"""Runtime probe for the outputs/ignore_for_cache interaction."""

import unittest

import parsl
from parsl import python_app
from parsl.config import Config
from parsl.executors.threads import ThreadPoolExecutor


class MemoIgnoreOutputsRuntimeTest(unittest.TestCase):
    def test_ignored_outputs_currently_gets_deleted_twice(self):
        @python_app(cache=True, ignore_for_cache=["outputs"])
        def app(outputs=[]):
            return 1

        with parsl.load(Config(executors=[ThreadPoolExecutor(max_threads=1)])):
            future = app(outputs=[])
            with self.assertRaises(KeyError):
                future.result()


if __name__ == "__main__":
    unittest.main()
