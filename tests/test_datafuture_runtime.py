"""Runtime probes for Parsl File/DataFuture readiness and dependencies."""

import pathlib
import tempfile
import unittest
from concurrent.futures import Future
from types import SimpleNamespace

import parsl
from parsl import Config, python_app
from parsl.app.futures import DataFuture
from parsl.data_provider.data_manager import DataManager
from parsl.data_provider.file_noop import NoOpFileStaging
from parsl.dataflow.errors import DependencyError
from parsl.data_provider.files import File
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def produce_file(outputs=[]):
    output_path = pathlib.Path(outputs[0].filepath)
    output_path.write_bytes(b"datafuture-ready\x00\xff")
    return "produced"


@python_app
def consume_file(inputs=[]):
    return pathlib.Path(inputs[0].filepath).read_bytes()


failure_consumer_calls = {"count": 0}


@python_app
def fail_to_produce(outputs=[]):
    raise ValueError("producer failed")


@python_app
def consume_after_failure(inputs=[]):
    failure_consumer_calls["count"] += 1
    return pathlib.Path(inputs[0].filepath).read_bytes()


class DataFutureRuntimeTest(unittest.TestCase):
    def test_stage_in_uses_clean_file_copy_and_preserves_parent(self):
        class FakeDFK:
            executors = {
                "fake": SimpleNamespace(storage_access=[NoOpFileStaging()]),
            }

        with tempfile.TemporaryDirectory() as directory:
            original = File(str(pathlib.Path(directory) / "input.bin"))
            original.local_path = "/site/local/input.bin"
            parent = Future()
            source = DataFuture(parent, original, tid=17)
            manager = DataManager(FakeDFK())

            staged, replacement = manager.optionally_stage_in(
                source, lambda value: value, "fake"
            )

            self.assertIsInstance(staged, DataFuture)
            self.assertIsNot(staged.file_obj, original)
            self.assertIs(staged.parent, source)
            self.assertIsNone(staged.file_obj.local_path)
            self.assertEqual(original.local_path, "/site/local/input.bin")
            self.assertEqual(replacement("ok"), "ok")

    def test_dependent_app_waits_for_file_producer_and_reads_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "output.bin"
            file_obj = File(str(path))
            config = Config(executors=[ThreadPoolExecutor(max_threads=2)])

            with parsl.load(config):
                producer = produce_file(outputs=[file_obj])
                consumer = consume_file(inputs=[file_obj])

                self.assertEqual(producer.result(), "produced")
                self.assertEqual(consumer.result(), b"datafuture-ready\x00\xff")

            self.assertEqual(path.read_bytes(), b"datafuture-ready\x00\xff")

    def test_failed_output_future_blocks_dependent_app(self):
        failure_consumer_calls["count"] = 0
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "missing.bin"
            config = Config(executors=[ThreadPoolExecutor(max_threads=2)])

            with parsl.load(config):
                producer = fail_to_produce(outputs=[File(str(path))])
                consumer = consume_after_failure(inputs=[producer.outputs[0]])

                self.assertIsInstance(producer.exception(), ValueError)
                self.assertIsInstance(consumer.exception(), DependencyError)

            self.assertEqual(failure_consumer_calls["count"], 0)
            self.assertFalse(path.exists())


if __name__ == "__main__":
    unittest.main()
