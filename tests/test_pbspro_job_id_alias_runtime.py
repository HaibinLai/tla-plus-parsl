"""Runtime probes for PBS Pro short and fully qualified job-id aliasing."""

import json
import unittest

from parsl.jobs.states import JobState, JobStatus
from parsl.providers.pbspro.pbspro import PBSProProvider


class PBSProJobIdAliasRuntimeTest(unittest.TestCase):
    @staticmethod
    def make_provider(jobs):
        provider = PBSProProvider.__new__(PBSProProvider)
        provider.resources = {
            "42.server": {
                "status": JobStatus(JobState.PENDING),
                "job_stdout_path": "out-42",
                "job_stderr_path": "err-42",
            },
        }
        payload = json.dumps({"Jobs": jobs})
        provider.execute_wait = lambda command: (0, payload, "")
        return provider

    def test_short_and_long_json_ids_alias_and_raise_value_error(self):
        provider = self.make_provider({
            "42": {"job_state": "R"},
            "42.server": {"job_state": "R"},
        })

        with self.assertRaises(ValueError):
            provider._status()

        self.assertEqual(provider.resources["42.server"]["status"].state,
                         JobState.RUNNING)

    def test_single_short_json_id_updates_long_local_resource(self):
        provider = self.make_provider({"42": {"job_state": "R"}})

        provider._status()

        self.assertEqual(provider.resources["42.server"]["status"].state,
                         JobState.RUNNING)


if __name__ == "__main__":
    unittest.main()
