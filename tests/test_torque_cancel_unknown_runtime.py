"""Runtime probe for idempotent Torque cancellation of stale IDs."""

import unittest
from unittest.mock import patch

from parsl.providers.cluster_provider import ClusterProvider
from parsl.providers.torque.torque import TorqueProvider


class TorqueCancelUnknownRuntimeTest(unittest.TestCase):
    def test_successful_qdel_for_stale_id_raises_key_error_currently(self):
        provider = TorqueProvider.__new__(TorqueProvider)
        provider.resources = {}

        with patch.object(ClusterProvider, "execute_wait", return_value=(0, "", "")):
            with self.assertRaises(KeyError):
                provider.cancel(["stale-job"])


if __name__ == "__main__":
    unittest.main()
