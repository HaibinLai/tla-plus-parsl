"""Runtime probe for Kubernetes cancellation after local resource cleanup."""

import unittest

from parsl.providers.kubernetes.kube import KubernetesProvider


class KubernetesCancelUnknownRuntimeTest(unittest.TestCase):
    def test_stale_cancel_raises_from_missing_resource(self):
        provider = KubernetesProvider.__new__(KubernetesProvider)
        provider.resources = {}

        with self.assertRaises(KeyError):
            provider.cancel(["stale-job"])


if __name__ == "__main__":
    unittest.main()
