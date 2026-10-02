import unittest

from parsl.executors.status_handling import BlockProviderExecutor
from parsl.jobs.states import JobState, JobStatus
from parsl.providers.slurm.slurm import SlurmProvider


class ProbeExecutor(BlockProviderExecutor):
    def outstanding(self):
        return 0

    @property
    def workers_per_node(self):
        return 1

    def _get_launch_command(self, block_id):
        return "true"

    def submit(self, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self, *args, **kwargs):
        return None


class SlurmCancelScaleInMonitoringRuntimeTest(unittest.TestCase):
    def test_stale_slurm_id_aborts_executor_terminal_propagation_currently(self):
        provider = SlurmProvider.__new__(SlurmProvider)
        provider.clusters = None
        provider.resources = {"known": {"status": JobStatus(JobState.RUNNING)}}
        provider.execute_wait = lambda command: (0, "", "")

        executor = ProbeExecutor(provider=provider, block_error_handler=False)
        executor._status = {
            "block-known": JobStatus(JobState.RUNNING),
            "block-stale": JobStatus(JobState.RUNNING),
        }
        executor.blocks_to_job_id = {
            "block-known": "known",
            "block-stale": "stale",
        }
        executor.job_ids_to_block = {
            "known": "block-known",
            "stale": "block-stale",
        }

        with self.assertRaises(KeyError):
            executor.scale_in_facade(2)

        self.assertEqual(executor._status["block-known"].state, JobState.RUNNING)
        self.assertEqual(executor._status["block-stale"].state, JobState.RUNNING)
        self.assertEqual(provider.resources["known"]["status"].state, JobState.CANCELLED)


if __name__ == "__main__":
    unittest.main()
