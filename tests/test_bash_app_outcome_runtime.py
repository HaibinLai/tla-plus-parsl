"""Runtime bridge for bash_app exit, output, and Future semantics."""

import tempfile
import unittest
from pathlib import Path

import parsl
from parsl import Config, File, bash_app
from parsl.app.errors import BashExitFailure
from parsl.executors.threads import ThreadPoolExecutor


@bash_app
def bash_success(**kwargs):
    return "printf 'bash-runtime\\n'"


@bash_app
def bash_failure(**kwargs):
    return "printf 'partial\\n'; exit 7"


@bash_app
def bash_output(path, **kwargs):
    return f"printf 'output-runtime\\n' > {path}"


class BashAppOutcomeRuntimeTest(unittest.TestCase):
    def test_exit_and_future_outcome(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "result.txt"
            config = Config(executors=[ThreadPoolExecutor(max_threads=1)])
            with parsl.load(config):
                success = bash_success(stdout=File(str(output)))
                self.assertEqual(success.result(), 0)
                self.assertIsNone(success.exception())
                self.assertEqual(output.read_text(), "bash-runtime\n")

                failure = bash_failure()
                with self.assertRaises(BashExitFailure):
                    failure.result()
                self.assertIsInstance(failure.exception(), BashExitFailure)

    def test_declared_output_must_exist_before_success(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "generated.txt"
            config = Config(executors=[ThreadPoolExecutor(max_threads=1)])
            with parsl.load(config):
                app = bash_output(str(output), outputs=[File(str(output))])
                self.assertEqual(app.result(), 0)
                self.assertTrue(output.exists())


if __name__ == "__main__":
    unittest.main()
