"""Runtime probe for the Flux provider-to-manager startup handshake."""

import unittest

from parsl.executors.flux.executor import _check_provider_job
from parsl.jobs.states import JobState, JobStatus


class ReadableSocket:
    def poll(self, timeout, flags):
        return 1


class TerminalProvider:
    def status(self, job_ids):
        return [JobStatus(JobState.COMPLETED)]


def fixed_check_provider_job(socket, provider, job_id):
    """Reference guard required before accepting a queued handshake frame."""
    if provider.status([job_id])[0].terminal:
        raise RuntimeError("provider job terminated before handshake acceptance")
    _check_provider_job(socket, provider, job_id)


class FluxProviderHandshakeRuntimeTest(unittest.TestCase):
    def test_current_accepts_readable_handshake_after_provider_termination(self):
        # The concrete helper returns immediately when poll() reports data and
        # does not inspect provider.status in that branch.
        _check_provider_job(ReadableSocket(), TerminalProvider(), "provider-1")

    def test_fixed_guard_rejects_terminal_provider_before_acceptance(self):
        with self.assertRaises(RuntimeError):
            fixed_check_provider_job(ReadableSocket(), TerminalProvider(), "provider-1")


if __name__ == "__main__":
    unittest.main()
