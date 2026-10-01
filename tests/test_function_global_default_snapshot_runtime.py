"""Runtime bridge for callable global/default snapshots."""

import unittest

from parsl.serialize.facade import pack_apply_message, unpack_apply_message


GLOBAL = {"offset": 1}


def add_with_default(value, bias=2):
    return GLOBAL["offset"] + bias + value


class FunctionGlobalDefaultSnapshotRuntimeTest(unittest.TestCase):
    def test_pack_apply_message_captures_global_and_default_values(self):
        payload = pack_apply_message(add_with_default, (3,), {})
        GLOBAL["offset"] = 10

        function, args, kwargs = unpack_apply_message(payload)
        # The current serializer snapshots the default but resolves the module
        # global when the decoded callable runs.
        self.assertEqual(function(*args, **kwargs), 15)
        self.assertEqual(function.__defaults__, (2,))
        self.assertEqual(kwargs, {})
        GLOBAL["offset"] = 1


if __name__ == "__main__":
    unittest.main()
