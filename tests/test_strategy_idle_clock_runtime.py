"""Runtime bridge for Strategy idle scale-in wall-clock rollback."""

import unittest
from unittest.mock import patch

from parsl.jobs.states import JobState, JobStatus
from parsl.jobs.strategy import Strategy


class FakeProvider:
    init_blocks = 0
    min_blocks = 1
    max_blocks = 4
    nodes_per_block = 1
    parallelism = 1.0


class FakeExecutor:
    label = "fake"
    provider = FakeProvider()
    workers_per_node = 1
    bad_state_is_set = False

    def __init__(self):
        self.status_facade = {
            "b0": JobStatus(JobState.RUNNING),
            "b1": JobStatus(JobState.RUNNING),
            "b2": JobStatus(JobState.RUNNING),
        }
        self.scale_in_calls = []
        self.scale_out_calls = []

    def outstanding(self):
        return 0

    def scale_out_facade(self, blocks):
        self.scale_out_calls.append(blocks)

    def scale_in_facade(self, blocks, **kwargs):
        self.scale_in_calls.append((blocks, kwargs))


class StrategyIdleClockRuntimeTest(unittest.TestCase):
    def test_wall_clock_rollback_suppresses_due_idle_scale_in_currently(self):
        executor = FakeExecutor()
        strategy = Strategy(strategy="simple", max_idletime=5)
        strategy.add_executors([executor])
        strategy.strategize([executor])
        strategy.executors[executor.label]["idle_since"] = 100.0

        with patch("parsl.jobs.strategy.time.time", return_value=90.0):
            strategy.strategize([executor])

        self.assertEqual(executor.scale_in_calls, [])


if __name__ == "__main__":
    unittest.main()
