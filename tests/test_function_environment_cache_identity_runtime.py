"""Runtime probe for callable environment-cache identity reuse."""

import unittest
from unittest.mock import patch

from parsl.executors.workqueue import executor as workqueue_executor


class FunctionEnvironmentCacheIdentityRuntimeTest(unittest.TestCase):
    def test_recycled_callable_id_returns_old_environment_package_currently(self):
        executor = workqueue_executor.WorkQueueExecutor.__new__(
            workqueue_executor.WorkQueueExecutor
        )
        executor.cached_envs = {42: "/tmp/package-old.tar.gz"}

        def new_function():
            return "new-imports"

        # Force the id-reuse interleaving at the cache boundary. The helper
        # returns before inspecting the new function, proving the stale hit.
        with patch.object(workqueue_executor, "id", lambda _fn: 42, create=True):
            package = executor._prepare_package(new_function, [])

        self.assertEqual(package, "/tmp/package-old.tar.gz")


if __name__ == "__main__":
    unittest.main()
