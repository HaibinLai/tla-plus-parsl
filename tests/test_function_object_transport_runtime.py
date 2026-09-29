"""Runtime probe for callable and closure-content snapshotting."""

import unittest

from parsl.serialize.facade import pack_apply_message, unpack_apply_message


def make_adder(box):
    def add(value):
        return value + box["offset"]

    return add


class FunctionObjectTransportRuntimeTest(unittest.TestCase):
    def test_closure_content_is_captured_before_source_mutation(self):
        box = {"offset": 3}
        payload = pack_apply_message(make_adder(box), (4,), {})

        # The bytes are already the transport snapshot; changing the source
        # object must not change the callable reconstructed from those bytes.
        box["offset"] = 99
        decoded_func, decoded_args, decoded_kwargs = unpack_apply_message(payload)

        self.assertEqual(decoded_func(*decoded_args, **decoded_kwargs), 7)
        self.assertEqual(decoded_args, (4,))
        self.assertEqual(decoded_kwargs, {})


if __name__ == "__main__":
    unittest.main()
