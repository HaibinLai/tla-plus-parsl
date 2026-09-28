"""Runtime probe for function-body identity in BasicMemoizer keys."""

import unittest

from parsl.dataflow.memoization import make_hash


def version_one():
    return "one"


def version_two():
    return "two"


def task_for(function):
    return {
        "kwargs": {},
        "func": function,
        "args": (),
        "ignore_for_cache": [],
    }


class MemoFunctionIdentityRuntimeTest(unittest.TestCase):
    def test_changed_function_body_keeps_same_memo_key_currently(self):
        # Simulate a code replacement that keeps the public function identity.
        version_one.__name__ = "same_entrypoint"
        version_two.__name__ = "same_entrypoint"
        version_one.__module__ = "same_module"
        version_two.__module__ = "same_module"

        self.assertNotEqual(version_one(), version_two())
        self.assertEqual(
            make_hash(task_for(version_one)),
            make_hash(task_for(version_two)),
        )


if __name__ == "__main__":
    unittest.main()
