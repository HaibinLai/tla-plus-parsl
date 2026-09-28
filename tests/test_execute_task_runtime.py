"""Runtime probes for the executor-side apply-message decoding boundary."""

import unittest

from parsl.executors.execute_task import execute_task
from parsl.serialize.facade import pack_apply_message


class ExecuteTaskRuntimeTest(unittest.TestCase):
    def test_decodes_and_invokes_callable_with_arguments(self):
        def combine(prefix, value=0):
            return f"{prefix}:{value}"

        message = pack_apply_message(combine, ("item",), {"value": 7})
        self.assertEqual(execute_task(message), "item:7")

    def test_user_exception_crosses_execution_boundary(self):
        def fails():
            raise ValueError("from worker")

        with self.assertRaises(ValueError):
            execute_task(pack_apply_message(fails, (), {}))

    def test_malformed_message_is_rejected_before_invocation(self):
        with self.assertRaises((ValueError, IndexError)):
            execute_task(b"not-a-packed-message")


if __name__ == "__main__":
    unittest.main()
