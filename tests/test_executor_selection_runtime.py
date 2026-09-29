"""Runtime probe for empty executor-list validation at app submission."""

import unittest

import parsl
from parsl import python_app
from parsl.config import Config
from parsl.executors.threads import ThreadPoolExecutor


class ExecutorSelectionRuntimeTest(unittest.TestCase):
    def test_empty_executor_list_currently_exposes_index_error(self):
        @python_app(executors=[])
        def app():
            return 1

        with self.assertRaises(IndexError):
            with parsl.load(Config(executors=[ThreadPoolExecutor(max_threads=1)])):
                app()


if __name__ == "__main__":
    unittest.main()
