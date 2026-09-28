"""Runtime probe for closure contents versus Parsl memoization identity."""

import unittest

from parsl.dataflow.memoization import make_hash
from parsl.serialize import serialize


def make_adder(offset):
    def add(value):
        return value + offset

    return add


def task_for(function):
    return {
        "kwargs": {},
        "func": function,
        "args": (),
        "ignore_for_cache": [],
    }


class MemoClosureRuntimeTest(unittest.TestCase):
    def test_closure_payloads_differ_but_current_memo_keys_collide(self):
        first = make_adder(1)
        second = make_adder(2)

        self.assertNotEqual(serialize(first), serialize(second))
        self.assertEqual(make_hash(task_for(first)), make_hash(task_for(second)))


if __name__ == "__main__":
    unittest.main()
