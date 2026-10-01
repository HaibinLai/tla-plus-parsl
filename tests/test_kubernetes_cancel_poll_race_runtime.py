"""Runtime probe for a Kubernetes poll racing with local cancellation."""

import unittest
from unittest.mock import Mock

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.kubernetes.kube import KubernetesProvider


class ReentrantPodClient:
    class Pod:
        status = type("PodStatus", (), {"phase": "Succeeded"})()

    def __init__(self, provider):
        self.provider = provider

    def read_namespaced_pod(self, **kwargs):
        # _status() snapshots the running job before this read.  Cancellation
        # can complete while the API call is in flight.
        self.provider.cancel(["job-1"])
        return self.Pod()


class KubernetesCancelPollRaceRuntimeTest(unittest.TestCase):
    def test_late_poll_overwrites_cancelled_state_currently(self):
        provider = KubernetesProvider.__new__(KubernetesProvider)
        provider.resources = {
            "job-1": {
                "status": JobStatus(JobState.RUNNING),
                "pod_name": "parsl.kube.job-1",
            }
        }
        provider.namespace = "default"
        provider._get_pod_name = lambda job_id: "parsl.kube.job-1"
        provider._delete_pod = Mock()
        provider.kube_client = ReentrantPodClient(provider)

        provider._status()

        # The source writes the successful API phase after cancel() has already
        # published CANCELLED, so the user-visible state becomes COMPLETED.
        self.assertEqual(provider.resources["job-1"]["status"].state,
                         JobState.COMPLETED)


if __name__ == "__main__":
    unittest.main()
