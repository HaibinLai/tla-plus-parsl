"""Runtime probes for the bounded Parsl scaling strategy abstraction."""

import unittest
from unittest.mock import patch

from parsl.jobs.states import JobState, JobStatus
from parsl.jobs.strategy import Strategy


class FakeProvider:
    def __init__(self, *, init_blocks=0, min_blocks=0, max_blocks=4,
                 nodes_per_block=1, parallelism=1.0):
        self.init_blocks = init_blocks
        self.min_blocks = min_blocks
        self.max_blocks = max_blocks
        self.nodes_per_block = nodes_per_block
        self.parallelism = parallelism


class FakeExecutor:
    def __init__(self, provider, *, workers_per_node=1,
                 outstanding_tasks=0, block_states=None):
        self.label = "fake"
        self.provider = provider
        self.workers_per_node = workers_per_node
        self.bad_state_is_set = False
        self._outstanding_tasks = outstanding_tasks
        self.status_facade = {
            f"block-{idx}": JobStatus(state)
            for idx, state in enumerate(block_states or [])
        }
        self.scale_out_calls = []
        self.scale_in_calls = []

    def outstanding(self):
        return self._outstanding_tasks

    def scale_out_facade(self, blocks):
        self.scale_out_calls.append(blocks)

    def scale_in_facade(self, blocks, **kwargs):
        self.scale_in_calls.append((blocks, kwargs))


class StrategyRuntimeTest(unittest.TestCase):
    def test_init_only_scales_once(self):
        provider = FakeProvider(init_blocks=2)
        executor = FakeExecutor(provider)
        strategy = Strategy(strategy="none", max_idletime=10)
        strategy.add_executors([executor])

        strategy.strategize([executor])
        strategy.strategize([executor])

        self.assertEqual(executor.scale_out_calls, [2])

    def test_simple_strategy_requests_capacity_for_overload(self):
        provider = FakeProvider(max_blocks=4, parallelism=1.0)
        executor = FakeExecutor(
            provider,
            outstanding_tasks=3,
            block_states=[JobState.RUNNING],
        )
        strategy = Strategy(strategy="simple", max_idletime=10)
        strategy.add_executors([executor])

        strategy.strategize([executor])

        # The first strategy poll also records the configured zero-block
        # initialization request before applying the overload rule. One active
        # slot serves three tasks, so two more blocks are needed.
        self.assertEqual(executor.scale_out_calls, [0, 2])

    def test_idle_scale_in_waits_and_preserves_minimum(self):
        provider = FakeProvider(min_blocks=1, max_blocks=4)
        executor = FakeExecutor(
            provider,
            block_states=[JobState.RUNNING, JobState.RUNNING, JobState.PENDING],
        )
        strategy = Strategy(strategy="simple", max_idletime=5)
        strategy.add_executors([executor])

        # Let the first poll start the timer, then set a deterministic elapsed
        # interval for the second poll. A constant patch also covers incidental
        # time reads made by logging in the strategy decorator.
        strategy.strategize([executor])
        self.assertEqual(executor.scale_in_calls, [])
        strategy.executors[executor.label]["idle_since"] = 100.0
        with patch("parsl.jobs.strategy.time.time", return_value=106.0):
            strategy.strategize([executor])

        self.assertEqual(executor.scale_in_calls, [(2, {})])

    def test_zero_nodes_per_block_crashes_overloaded_strategy_currently(self):
        provider = FakeProvider(nodes_per_block=0, parallelism=1.0)
        executor = FakeExecutor(provider, outstanding_tasks=1)
        strategy = Strategy(strategy="simple", max_idletime=10)
        strategy.add_executors([executor])

        with self.assertRaises(ZeroDivisionError):
            strategy.strategize([executor])

        self.assertEqual(executor.scale_out_calls, [0])


if __name__ == "__main__":
    unittest.main()
