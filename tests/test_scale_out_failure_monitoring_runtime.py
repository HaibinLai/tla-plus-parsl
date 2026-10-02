"""Runtime probe for block provisioning failure monitoring."""

import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.executors.status_handling import BlockProviderExecutor


class FailingProvider:
    def submit(self, command, tasks_per_node, job_name):
        raise RuntimeError("provider rejected allocation")


class PartialProvider:
    def __init__(self):
        self.calls = 0

    def submit(self, command, tasks_per_node, job_name):
        self.calls += 1
        if self.calls == 1:
            return "job-0"
        raise RuntimeError("provider rejected second allocation")

    def status(self, job_ids):
        self.status_calls = getattr(self, "status_calls", [])
        self.status_calls.append(list(job_ids))
        return [JobStatus(JobState.PENDING) for _ in job_ids]


class RecordingRadio:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class DummyBlockExecutor(BlockProviderExecutor):
    def __init__(self, provider):
        super().__init__(provider=provider, block_error_handler=False)
        self.submit_monitoring_radio = RecordingRadio()

    def outstanding(self):
        return 0

    def _get_launch_command(self, block_id):
        return "launch"

    def submit(self, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self):
        pass

    @property
    def workers_per_node(self):
        return 1


class ScaleOutFailureMonitoringRuntimeTest(unittest.TestCase):
    def test_failed_provisioning_is_stored_but_not_reported(self):
        executor = DummyBlockExecutor(FailingProvider())

        self.assertEqual(executor.scale_out_facade(1), [])
        self.assertEqual(executor._status["0"].status_name, "FAILED")
        self.assertEqual(len(executor.submit_monitoring_radio.messages), 1)
        # The radio is notified, but its BLOCK_INFO payload omits the failed block.
        self.assertEqual(executor.submit_monitoring_radio.messages[0][1], [])

    def test_partial_scale_out_reports_success_but_omits_failure(self):
        executor = DummyBlockExecutor(PartialProvider())

        self.assertEqual(executor.scale_out_facade(2), ["0"])
        self.assertEqual(executor._status["0"].status_name, "PENDING")
        self.assertEqual(executor._status["1"].status_name, "FAILED")
        payload = executor.submit_monitoring_radio.messages[0][1]
        self.assertEqual([entry["block_id"] for entry in payload], ["0"])

    def test_status_keeps_simulated_failure_separate_from_provider_jobs(self):
        provider = PartialProvider()
        executor = DummyBlockExecutor(provider)

        self.assertEqual(executor.scale_out_facade(2), ["0"])
        status = executor.status()

        self.assertEqual(provider.status_calls, [["job-0"]])
        self.assertEqual(status["0"].status_name, "PENDING")
        self.assertEqual(status["1"].status_name, "FAILED")
        self.assertEqual(executor.blocks_to_job_id, {"0": "job-0"})
        self.assertEqual(executor.job_ids_to_block, {"job-0": "0"})


if __name__ == "__main__":
    unittest.main()
