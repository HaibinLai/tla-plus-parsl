"""Runtime probes for Kubernetes pod deletion and cancellation state."""

import unittest
from unittest.mock import Mock

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.kubernetes.kube import KubernetesProvider


class KubernetesCancelRuntimeTest(unittest.TestCase):
    def provider_with_delete(self, delete):
        provider = KubernetesProvider.__new__(KubernetesProvider)
        provider.resources = {
            "job-1": {
                "status": JobStatus(JobState.RUNNING),
                "pod_name": "parsl.kube.job-1",
            }
        }
        provider._delete_pod = delete
        return provider

    def test_successful_delete_marks_cancelled(self):
        delete = Mock()
        provider = self.provider_with_delete(delete)

        self.assertEqual(provider.cancel(["job-1"]), [True])
        delete.assert_called_once_with("parsl.kube.job-1")
        self.assertEqual(provider.resources["job-1"]["status"].state, JobState.CANCELLED)

    def test_delete_error_propagates_before_state_update(self):
        provider = self.provider_with_delete(Mock(side_effect=RuntimeError("api down")))

        with self.assertRaises(RuntimeError):
            provider.cancel(["job-1"])
        self.assertEqual(provider.resources["job-1"]["status"].state, JobState.RUNNING)

    def test_returned_delete_error_is_ignored_by_current_source(self):
        provider = self.provider_with_delete(Mock(return_value={"status": "Failure"}))

        self.assertEqual(provider.cancel(["job-1"]), [True])
        self.assertEqual(provider.resources["job-1"]["status"].state, JobState.CANCELLED)


if __name__ == "__main__":
    unittest.main()
