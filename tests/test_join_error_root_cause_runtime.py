"""Runtime probes for JoinError root-cause and representative path semantics."""

import unittest

from parsl.dataflow.errors import JoinError


class JoinErrorRootCauseRuntimeTest(unittest.TestCase):
    def test_nested_join_error_selects_first_leaf_and_marks_siblings(self):
        leaf = ValueError("leaf failure")
        inner = JoinError([(leaf, "leaf")], task_id=2)
        outer = JoinError(
            [(inner, "inner"), (RuntimeError("other"), "other")],
            task_id=3,
        )

        self.assertIs(outer.__cause__, leaf)
        self.assertEqual(
            str(outer),
            "Join failure for task 3. The representative cause is via inner (+ others) <- leaf",
        )


if __name__ == "__main__":
    unittest.main()
