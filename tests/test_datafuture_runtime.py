"""Runtime probes for Parsl File/DataFuture readiness and dependencies."""

import pathlib
import tempfile
import unittest

import parsl
from parsl import Config, python_app
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


class DataFutureRuntimeTest(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
