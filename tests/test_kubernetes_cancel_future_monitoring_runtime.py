"""Runtime bridge for Kubernetes delete response and cancellation propagation."""

import unittest
from unittest.mock import Mock

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.kubernetes.kube import KubernetesProvider


class KubernetesCancelFutureMonitoringRuntimeTest(unittest.TestCase):
    def provider(self):
        provider = KubernetesProvider.__new__(KubernetesProvider)
        provider.resources = {
            "job-1": {
                "status": JobStatus(JobState.RUNNING),
                "pod_name": "parsl.kube.job-1",
            }
        }
        provider._get_pod_name = lambda job_id: provider.resources[job_id]["pod_name"]
        provider._delete_pod = Mock(return_value={"status": "Failure"})
        return provider

    def test_current_propagates_cancelled_state_after_failed_delete(self):
        provider = self.provider()

        result = provider.cancel(["job-1"])

        # Current source ignores the API response and reports cancellation to
        # every upper layer even though the remote delete failed.
        self.assertEqual(result, [True])
        self.assertEqual(provider.resources["job-1"]["status"].state, JobState.CANCELLED)

    def test_candidate_fixed_gate_rejects_failed_delete(self):
        provider = self.provider()
        response = provider._delete_pod("parsl.kube.job-1")
        self.assertEqual(response["status"], "Failure")
        # A fixed provider would leave the Future/monitoring state pending and
        # return a failed cancellation until the remote API confirms deletion.
        self.assertEqual(provider.resources["job-1"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
