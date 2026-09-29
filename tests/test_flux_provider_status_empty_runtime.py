"""Runtime probe for Flux provider status responses with no entries."""

import unittest
from parsl.executors.flux.executor import _check_provider_job


class EmptyStatusProvider:
    def status(self, job_ids):
        return []


class PollingSocket:
    def poll(self, timeout, event):
        return 0


class FluxProviderStatusEmptyRuntimeTest(unittest.TestCase):
    def test_empty_status_is_not_handled_as_a_provider_state(self):
        # Current source indexes status(...)[0] without checking cardinality.
        with self.assertRaises(IndexError):
            _check_provider_job(PollingSocket(), EmptyStatusProvider(), "job-1")


if __name__ == "__main__":
    unittest.main()
