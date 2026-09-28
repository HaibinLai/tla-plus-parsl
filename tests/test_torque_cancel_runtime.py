"""Runtime probes for Torque provider cancellation outcomes."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.torque.torque import TorqueProvider


class TorqueCancelRuntimeTest(unittest.TestCase):
    def provider_with_result(self, result):
        provider = TorqueProvider.__new__(TorqueProvider)
        provider.resources = {
            "42.server": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.execute_wait = lambda command: result
        return provider

    def test_successful_qdel_returns_true_and_marks_exiting_as_completed(self):
        provider = self.provider_with_result((0, "", ""))

        result = provider.cancel(["42.server"])

        self.assertEqual(result, [True])
        # Torque's implementation treats successful qdel as an exiting/completed
        # resource state; this is distinct from provider cancellation bookkeeping.
        self.assertEqual(provider.resources["42.server"]["status"].state, JobState.COMPLETED)

    def test_failed_qdel_returns_false_and_preserves_status(self):
        provider = self.provider_with_result((1, "", "qdel failed"))

        result = provider.cancel(["42.server"])

        self.assertEqual(result, [False])
        self.assertEqual(provider.resources["42.server"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
