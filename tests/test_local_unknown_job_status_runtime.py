"""Runtime probe for LocalProvider status after local resource cleanup."""

import unittest

from parsl.providers.local.local import LocalProvider


class LocalUnknownJobStatusRuntimeTest(unittest.TestCase):
    def test_stale_job_id_aborts_status_result_lookup(self):
        provider = LocalProvider()
        provider.resources["local-job"] = {"status": None}
        provider.resources.pop("local-job")

        with self.assertRaises(KeyError):
            provider.status(["local-job"])


if __name__ == "__main__":
    unittest.main()
