"""Runtime probe for Kubernetes provider read-error status handling."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.kubernetes.kube import KubernetesProvider


class FailingKubernetesClient:
    def read_namespaced_pod(self, **kwargs):
        raise RuntimeError("pod disappeared")


class RunningKubernetesClient:
    class Pod:
        def __init__(self):
            self.status = type("PodStatus", (), {"phase": "Succeeded"})()

    def read_namespaced_pod(self, **kwargs):
        return self.Pod()


class EmptyPhaseKubernetesClient:
    class Pod:
        def __init__(self):
            self.status = type("PodStatus", (), {"phase": None})()

    def read_namespaced_pod(self, **kwargs):
        return self.Pod()


class KubernetesPollingRuntimeTest(unittest.TestCase):
    def provider_with_client(self, client):
        provider = KubernetesProvider.__new__(KubernetesProvider)
        provider.resources = {
            "job-1": {"status": JobStatus(JobState.RUNNING)},
        }
        provider.kube_client = client
        provider.namespace = "default"
        provider._get_pod_name = lambda job_id: "pod-" + job_id
        return provider

    def test_read_error_reproduces_running_status_regression(self):
        provider = self.provider_with_client(FailingKubernetesClient())

        provider._status()

        # Current source uses identity comparison (`is JobStatus(...)`), so this
        # branch does not set phase to Unknown and leaves RUNNING unchanged.
        self.assertEqual(provider.resources["job-1"]["status"].state, JobState.RUNNING)

    def test_successful_read_translates_terminal_phase(self):
        provider = self.provider_with_client(RunningKubernetesClient())

        provider._status()

        self.assertEqual(provider.resources["job-1"]["status"].state, JobState.COMPLETED)

    def test_successful_read_with_missing_phase_leaves_running_currently(self):
        provider = self.provider_with_client(EmptyPhaseKubernetesClient())

        provider._status()

        self.assertEqual(provider.resources["job-1"]["status"].state, JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
