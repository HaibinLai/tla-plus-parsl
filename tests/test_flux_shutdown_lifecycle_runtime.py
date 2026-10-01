"""Runtime bridge for FluxExecutor shutdown before start."""

import unittest
from unittest.mock import patch

from parsl.executors.flux.executor import FluxExecutor


class FluxShutdownLifecycleRuntimeTest(unittest.TestCase):
    def test_shutdown_before_start_joins_unstarted_thread_currently(self):
        # Avoid the constructor's weakref finalizer adding a second join error
        # at interpreter exit; the executor behavior under test is unchanged.
        with patch("parsl.executors.flux.executor.weakref.finalize", return_value=None):
            executor = FluxExecutor(flux_path="/bin/true")

        with self.assertRaises(RuntimeError):
            executor.shutdown()


if __name__ == "__main__":
    unittest.main()
