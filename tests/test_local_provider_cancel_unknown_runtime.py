"""Runtime probe for LocalProvider cancellation after resource removal."""

import unittest

from parsl.providers.local.local import LocalProvider


class LocalProviderCancelUnknownRuntimeTest(unittest.TestCase):
    def test_stale_job_id_raises_key_error_currently(self):
        provider = LocalProvider()
        provider.resources = {}

        with self.assertRaises(KeyError):
            provider.cancel(["already-removed"])


if __name__ == "__main__":
    unittest.main()
