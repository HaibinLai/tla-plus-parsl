"""Runtime probe for Flux jobspec preparation failure after dequeue."""

import sys
import types
import unittest
from unittest.mock import patch

from parsl.executors.flux import executor as flux_executor


class FailingJobspec:
    @classmethod
    def from_command(cls, **kwargs):
        raise ValueError("invalid Flux jobspec")


class FakeFluxJobModule:
    JobspecV1 = FailingJobspec


class FluxInflightSubmissionFailureRuntimeTest(unittest.TestCase):
    def test_jobspec_failure_leaves_dequeued_future_pending_currently(self):
        fake_flux = types.SimpleNamespace(job=FakeFluxJobModule)
        info = flux_executor._FluxJobInfo(
            future=flux_executor.FluxFutureWrapper(),
            task_id="0",
            infile="/work/0_in.pkl",
            outfile="/work/0_out.pkl",
            resource_spec={},
        )

        with patch.dict(sys.modules, {"flux": fake_flux, "flux.job": FakeFluxJobModule}):
            with self.assertRaises(ValueError):
                flux_executor._submit_single_job(object(), "/work", info)

        # The caller has already dequeued this job, so _error_out_jobs cannot
        # see it. The inspected source leaves its user-facing Future pending.
        self.assertFalse(info.future.done())


if __name__ == "__main__":
    unittest.main()
