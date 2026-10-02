"""Runtime bridge for Kubernetes submit state and task admission."""

import unittest
from unittest.mock import Mock, patch

from parsl.jobs.states import JobState
from parsl.providers.kubernetes.kube import KubernetesProvider


class PendingPod:
    status = type("PodStatus", (), {"phase": "Pending"})()


class KubernetesFutureAdmissionRuntimeTest(unittest.TestCase):
    def test_submit_publishes_running_before_pending_pod_is_polled(self):
        provider = KubernetesProvider.__new__(KubernetesProvider)
        provider.image = "worker:latest"
        provider.pod_name = None
        provider.worker_init = ""
        provider.persistent_volumes = []
        provider.service_account_name = None
        provider.annotations = None
        provider.namespace = "default"
        provider.resources = {}
        provider._create_pod = Mock()
        provider._get_pod_name = lambda job_id: provider.resources[job_id]["pod_name"]
        provider.kube_client = Mock()
        provider.kube_client.read_namespaced_pod.return_value = PendingPod()

        with patch("parsl.providers.kubernetes.kube.uuid.uuid4") as uuid4:
            uuid4.return_value.hex = "12345678deadbeef"
            job_id = provider.submit("echo worker", tasks_per_node=1)

        # An executor layered on the provider can observe RUNNING and admit a
        # Future before its first API poll proves that the pod is still Pending.
        admitted_before_poll = provider.resources[job_id]["status"].state == JobState.RUNNING
        provider.status([job_id])
        observed_pending = provider.resources[job_id]["status"].state == JobState.PENDING

        self.assertTrue(admitted_before_poll)
        self.assertTrue(observed_pending)


if __name__ == "__main__":
    unittest.main()
