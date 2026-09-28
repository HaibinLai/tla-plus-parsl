"""Runtime probe for heterogeneous dictionary keys in memoization."""

import unittest

from parsl.dataflow.memoization import make_hash


def task_for(function, kwargs):
    return {
        "kwargs": kwargs,
        "func": function,
        "args": (),
        "ignore_for_cache": [],
    }


def identity(value):
    return value


class MemoDictOrderingRuntimeTest(unittest.TestCase):
    def test_mixed_dict_keys_raise_during_hashing_currently(self):
        mixed = {1: "integer", "1": "string"}
        with self.assertRaises(TypeError):
            make_hash(task_for(identity, {"value": mixed}))


if __name__ == "__main__":
    unittest.main()
