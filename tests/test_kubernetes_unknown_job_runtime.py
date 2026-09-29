"""Runtime probe for Kubernetes status lookup of a stale local job id."""

import unittest

from parsl.providers.kubernetes.kube import KubernetesProvider


class KubernetesUnknownJobRuntimeTest(unittest.TestCase):
    def test_unknown_job_id_raises_key_error_currently(self):
        provider = KubernetesProvider.__new__(KubernetesProvider)
        provider.resources = {}
        provider._status = lambda: None

        with self.assertRaises(KeyError):
            provider.status(["stale-id"])


if __name__ == "__main__":
    unittest.main()
