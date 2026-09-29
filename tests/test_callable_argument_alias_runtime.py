"""Runtime probe for identity shared by a closure and an argument."""

import unittest

from parsl.serialize.facade import pack_apply_message, unpack_apply_message


def make_identity_probe(shared):
    def probe(value):
        return shared is value

    return probe


class CallableArgumentAliasRuntimeTest(unittest.TestCase):
    def test_current_message_format_breaks_cross_boundary_identity(self):
        shared = []
        packed = pack_apply_message(make_identity_probe(shared), (shared,), {})
        decoded, args, _ = unpack_apply_message(packed)

        # The callable and argument are serialized independently, so the
        # decoded objects compare equal but are not the same Python object.
        self.assertFalse(decoded(args[0]))
        self.assertEqual(decoded.__closure__[0].cell_contents, args[0])
        self.assertIsNot(decoded.__closure__[0].cell_contents, args[0])


if __name__ == "__main__":
    unittest.main()
