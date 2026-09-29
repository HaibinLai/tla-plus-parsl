"""Runtime probe for LocalProvider status after local resource cleanup."""

import unittest

from parsl.providers.local.local import LocalProvider


class LocalUnknownJobStatusRuntimeTest(unittest.TestCase):
    def test_stale_job_id_aborts_status_result_lookup(self):
        provider = LocalProvider()

        with self.assertRaises(KeyError):
            provider.status(["stale-local-job"])


if __name__ == "__main__":
    unittest.main()
