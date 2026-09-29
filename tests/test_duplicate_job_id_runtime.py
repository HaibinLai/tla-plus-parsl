"""Runtime probe for duplicate provider job IDs during scale-out."""

import unittest
from concurrent.futures import Future

from parsl.executors.status_handling import BlockProviderExecutor


class _DuplicateProvider:
    status_polling_interval = 1

    def submit(self, command, tasks_per_node, job_name):
        return "same-job-id"

    def cancel(self, job_ids):
        return [True for _ in job_ids]


class _Executor(BlockProviderExecutor):
    label = "duplicate-test"

    def __init__(self):
        super().__init__(provider=_DuplicateProvider(), block_error_handler=False)

    def submit(self, func, resource_specification, *args, **kwargs):
        return Future()

    def shutdown(self):
        pass

    def outstanding(self):
        return 0

    @property
    def workers_per_node(self):
        return 1

    def _get_launch_command(self, block_id):
        return "launch " + block_id


class DuplicateJobIdRuntimeTest(unittest.TestCase):
    def test_duplicate_provider_job_id_overwrites_reverse_ownership_currently(self):
        executor = _Executor()
        block_ids = executor.scale_out_facade(2)

        self.assertEqual(len(block_ids), 2)
        self.assertEqual(len(executor.blocks_to_job_id), 2)
        self.assertEqual(len(executor.job_ids_to_block), 1)
        self.assertNotEqual(set(executor.blocks_to_job_id), set(executor.job_ids_to_block.values()))


if __name__ == "__main__":
    unittest.main()
