"""Runtime bridge for JoinError exception-object identity propagation."""

import unittest

from parsl.dataflow.errors import JoinError


class JoinExceptionIdentityRuntimeTest(unittest.TestCase):
    def test_nested_join_error_keeps_leaf_exception_object_as_cause(self):
        leaf = ValueError("same object, not just equal text")
        inner = JoinError([(leaf, "inner")], task_id=7)
        outer = JoinError(
            [(inner, "nested"), (RuntimeError("sibling"), "sibling")],
            task_id=8,
        )

        self.assertIs(inner.__cause__, leaf)
        self.assertIs(outer.__cause__, leaf)
        self.assertIn("nested (+ others)", str(outer))


if __name__ == "__main__":
    unittest.main()
