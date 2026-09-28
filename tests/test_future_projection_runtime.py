"""Runtime probes for deferred AppFuture item and attribute projection."""

import unittest
from concurrent.futures import Future

import parsl
from parsl import Config, python_app
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def projection_dict():
    return {"value": 42}


@python_app
def projection_object():
    class Value:
        value = 7

    return Value()


@python_app
def projection_passthrough(value):
    return value


class FutureProjectionRuntimeTest(unittest.TestCase):
    def config(self):
        return Config(executors=[ThreadPoolExecutor(max_threads=2)])

    def test_getitem_creates_deferred_internal_task(self):
        with parsl.load(self.config()):
            projected = projection_dict()["value"]
            self.assertEqual(projected.result(), 42)

    def test_getattr_creates_deferred_internal_task(self):
        with parsl.load(self.config()):
            projected = projection_object().value
            self.assertEqual(projected.result(), 7)

    def test_invalid_item_becomes_projection_exception(self):
        with parsl.load(self.config()):
            projected = projection_dict()["missing"]
            self.assertIsInstance(projected.exception(), KeyError)

    def test_projection_creation_does_not_wait_synchronously(self):
        with parsl.load(self.config()):
            prerequisite = Future()
            top = projection_passthrough(prerequisite)
            projected = top["value"]
            prerequisite.set_result({"value": "ready"})
            self.assertEqual(projected.result(), "ready")


if __name__ == "__main__":
    unittest.main()
