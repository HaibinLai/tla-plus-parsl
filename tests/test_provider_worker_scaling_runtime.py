"""Runtime bridge for provider block and executor worker-capacity states."""

import unittest

from parsl.executors.status_handling import BlockProviderExecutor
from parsl.jobs.states import JobState, JobStatus


class ScalingProvider:
    status_polling_interval = 1

    def __init__(self):
        self.submitted = []
        self.cancelled = []

    def submit(self, command, tasks_per_node, job_name):
        job_id = "job-{}".format(len(self.submitted))
        self.submitted.append((job_id, command, tasks_per_node, job_name))
        return job_id

    def cancel(self, job_ids):
        self.cancelled.append(list(job_ids))
        return [True for _ in job_ids]


class ProbeExecutor(BlockProviderExecutor):
    def outstanding(self):
        return 0

    def _get_launch_command(self, block_id):
        return "launch-" + block_id

    def submit(self, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self):
        return None

    @property
    def workers_per_node(self):
        return 1


class ProviderWorkerScalingRuntimeTest(unittest.TestCase):
    def test_block_mapping_moves_from_pending_to_scaled_in(self):
        provider = ScalingProvider()
        executor = ProbeExecutor(provider=provider, block_error_handler=False)

        self.assertEqual(executor.scale_out_facade(1), ["0"])
        self.assertEqual(executor._status["0"].state, JobState.PENDING)
        self.assertEqual(executor.blocks_to_job_id, {"0": "job-0"})
        self.assertEqual(executor.job_ids_to_block, {"job-0": "0"})

        # A provider block is still only pending until status polling/manager
        # registration makes worker capacity available; scale-in then marks it
        # terminal and cancels the provider job through the same mapping.
        executor._status["0"] = JobStatus(JobState.RUNNING)
        self.assertEqual(executor.scale_in_facade(1), ["0"])
        self.assertEqual(provider.cancelled, [["job-0"]])
        self.assertEqual(executor._status["0"].state, JobState.SCALED_IN)


if __name__ == "__main__":
    unittest.main()
