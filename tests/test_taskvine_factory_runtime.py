"""Runtime probes for the TaskVine factory process boundary."""

import tempfile
import threading
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from parsl.executors.taskvine import factory as taskvine_factory


class FakeFactory:
    instances = []

    def __init__(self, **kwargs):
        self.constructor_kwargs = kwargs
        self.entered = False
        self.exited = False
        FakeFactory.instances.append(self)

    def __enter__(self):
        self.entered = True
        return self

    def __exit__(self, exc_type, exc, tb):
        self.exited = True
        return False


class TaskVineFactoryRuntimeTest(unittest.TestCase):
    def config(self, scratch_dir):
        return SimpleNamespace(
            _project_name="project-a",
            batch_type="local",
            _project_address=None,
            _project_port=0,
            _project_password_file=None,
            factory_timeout=17,
            scratch_dir=scratch_dir,
            min_workers=1,
            max_workers=3,
            workers_per_cycle=2,
            worker_options="--debug",
            worker_timeout=23,
            cores=4,
            gpus=1,
            memory=1024,
            disk=2048,
            python_env="env.tar.gz",
            condor_requirements=None,
            batch_options="--queue short",
        )

    def test_factory_is_configured_and_exits_after_stop_signal(self):
        FakeFactory.instances.clear()
        stop = threading.Event()
        stop.set()
        with tempfile.TemporaryDirectory() as scratch:
            config = self.config(scratch)
            with patch.object(taskvine_factory, "taskvine_available", True), \
                    patch.object(taskvine_factory, "Factory", FakeFactory, create=True):
                taskvine_factory._taskvine_factory(stop, config)

        self.assertEqual(len(FakeFactory.instances), 1)
        factory = FakeFactory.instances[0]
        self.assertTrue(factory.entered)
        self.assertTrue(factory.exited)
        self.assertEqual(factory.factory_timeout, 17)
        self.assertEqual(factory.timeout, 23)
        self.assertEqual(factory.min_workers, 1)
        self.assertEqual(factory.max_workers, 3)
        self.assertEqual(factory.workers_per_cycle, 2)
        self.assertEqual(factory.cores, 4)
        self.assertEqual(factory.gpus, 1)
        self.assertEqual(factory.memory, 1024)
        self.assertEqual(factory.disk, 2048)
        self.assertEqual(factory.python_env, "env.tar.gz")


if __name__ == "__main__":
    unittest.main()
