"""Runtime probe for Radical-Pilot empty master submission responses."""

import types
import unittest
from unittest.mock import patch

from parsl.executors.radical import executor as radical_executor


class FakeSession:
    uid = "session-1"
    path = "/tmp/session-1"


class FakePilot:
    description = {"cores": 1, "nodes": 1}

    def prepare_env(self, **kwargs):
        return None


class FakeTaskManager:
    def __init__(self, **kwargs):
        pass

    def add_pilots(self, pilot):
        return None

    def register_callback(self, callback):
        return None

    def submit_raptors(self, description):
        return []


class FakePilotManager:
    def __init__(self, **kwargs):
        pass

    def submit_pilots(self, description):
        return FakePilot()


class FakePilotDescription:
    def __init__(self, value):
        self.value = value

    def verify(self):
        return None


class RadicalMasterSubmitShapeRuntimeTest(unittest.TestCase):
    def test_empty_master_response_leaks_index_error_currently(self):
        executor = radical_executor.RadicalPilotExecutor.__new__(radical_executor.RadicalPilotExecutor)
        executor.run_dir = "."
        executor.label = "RPEX"
        executor.session = None
        executor.resource = "local.localhost"
        executor.bulk_mode = False
        executor.pilot_kwargs = {}
        executor.rpex_cfg = types.SimpleNamespace(
            n_masters=1,
            n_workers=0,
            master_descr={},
            worker_descr={},
            pilot_env_mode=radical_executor.CLIENT,
        )

        fake_rp = types.SimpleNamespace(
            version="fake",
            Session=lambda **kwargs: FakeSession(),
            PilotDescription=FakePilotDescription,
            TaskManager=FakeTaskManager,
            PilotManager=FakePilotManager,
            TaskDescription=lambda value: types.SimpleNamespace(),
        )
        fake_ru = types.SimpleNamespace(
            ID_PRIVATE="private",
            ID_CUSTOM="custom",
            generate_id=lambda *args, **kwargs: "generated-id",
        )

        with patch.object(radical_executor, "rp", fake_rp, create=True), patch.object(radical_executor, "ru", fake_ru, create=True):
            with self.assertRaises(IndexError):
                executor.start()

        self.assertEqual(executor.masters, [])


if __name__ == "__main__":
    unittest.main()
