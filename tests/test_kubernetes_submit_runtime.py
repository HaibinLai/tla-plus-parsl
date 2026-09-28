"""Runtime probes for Kubernetes pod creation and initial resource state."""

import unittest
from unittest.mock import Mock, patch

from parsl.jobs.states import JobState
from parsl.providers.kubernetes.kube import KubernetesProvider


class KubernetesSubmitRuntimeTest(unittest.TestCase):
    def provider_with_create(self, create):
        provider = KubernetesProvider.__new__(KubernetesProvider)
        provider.image = "worker:latest"
        provider.pod_name = None
        provider.worker_init = ""
        provider.persistent_volumes = []
        provider.service_account_name = None
        provider.annotations = None
        provider.namespace = "default"
        provider.resources = {}
        provider._create_pod = create
        return provider

    def test_successful_create_is_recorded_running_by_current_source(self):
        create = Mock()
        provider = self.provider_with_create(create)
        with patch("parsl.providers.kubernetes.kube.uuid.uuid4") as uuid4:
            uuid4.return_value.hex = "12345678deadbeef"
            job_id = provider.submit("echo worker", tasks_per_node=1)

        self.assertEqual(job_id, "12345678")
        create.assert_called_once()
        self.assertEqual(provider.resources[job_id]["status"].state, JobState.RUNNING)

    def test_create_api_error_does_not_register_resource(self):
        provider = self.provider_with_create(Mock(side_effect=RuntimeError("api down")))
        with patch("parsl.providers.kubernetes.kube.uuid.uuid4") as uuid4:
            uuid4.return_value.hex = "12345678deadbeef"
            with self.assertRaises(RuntimeError):
                provider.submit("echo worker", tasks_per_node=1)

        self.assertEqual(provider.resources, {})


if __name__ == "__main__":
    unittest.main()
