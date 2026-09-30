"""Runtime probe for nested callable/argument alias identity."""

import unittest

from parsl.serialize.facade import pack_apply_message, unpack_apply_message


def make_identity_probe(shared):
    def probe(argument):
        return shared is argument["nested"]

    return probe


class PythonNestedAliasRuntimeTest(unittest.TestCase):
    def test_callable_closure_and_nested_argument_are_not_shared_currently(self):
        shared = {"value": 7}
        payload = pack_apply_message(
            make_identity_probe(shared),
            ({"nested": shared},),
            {},
        )
        decoded, args, kwargs = unpack_apply_message(payload)

        self.assertFalse(decoded(*args, **kwargs))
        self.assertEqual(args[0]["nested"], shared)


if __name__ == "__main__":
    unittest.main()
