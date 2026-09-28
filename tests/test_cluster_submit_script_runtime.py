"""Runtime probes for ClusterProvider submit-script generation."""

import tempfile
import unittest
from pathlib import Path

from parsl.providers.cluster_provider import ClusterProvider
from parsl.providers.errors import SchedulerMissingArgs, ScriptPathError


class DummyClusterProvider(ClusterProvider):
    def __init__(self):
        pass

    def _status(self):
        return None

    def cancel(self, job_ids):
        return [True for _ in job_ids]

    def submit(self, *args, **kwargs):
        return "job"

    @property
    def status_polling_interval(self):
        return 1


class ClusterSubmitScriptRuntimeTest(unittest.TestCase):
    def provider(self):
        provider = DummyClusterProvider()
        provider._label = "test-cluster"
        return provider

    def test_valid_template_is_written(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "submit.sh"
            self.provider()._write_submit_script(
                "#!/bin/sh\necho $jobname", str(path), "job-1", {}
            )
            self.assertEqual(path.read_text(), "#!/bin/sh\necho job-1")

    def test_missing_template_key_maps_to_scheduler_error(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(SchedulerMissingArgs):
                self.provider()._write_submit_script(
                    "echo $missing", str(Path(directory) / "submit.sh"), "job-1", {}
                )

    def test_unwritable_target_maps_to_script_path_error(self):
        with self.assertRaises(ScriptPathError):
            self.provider()._write_submit_script(
                "echo job", "/definitely/missing/submit.sh", "job-1", {}
            )


if __name__ == "__main__":
    unittest.main()
