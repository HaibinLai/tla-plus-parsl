"""Runtime probes for Parsl's callable/data serialization boundary."""

import unittest

from parsl.serialize.facade import (
    pack_apply_message,
    unpack_buffers,
    serialize,
    unpack_apply_message,
)


class Unserializable:
    def __getstate__(self):
        raise RuntimeError("deliberately unserializable")


def make_adder(offset):
    def add(value):
        return offset + value

    return add


class SerializationRuntimeTest(unittest.TestCase):
    def test_truncated_buffer_is_currently_accepted_by_unpacker(self):
        # The framing model marks this as unsafe: the current implementation
        # returns the short slice instead of rejecting the declared-length
        # mismatch. This is a concrete counterexample for the fixed model.
        self.assertEqual(unpack_buffers(b"5\nabc"), [b"abc"])

    def test_closure_and_apply_message_round_trip(self):
        func = make_adder(7)
        packed = pack_apply_message(func, (5,), {"unused": None})

        decoded_func, decoded_args, decoded_kwargs = unpack_apply_message(packed)

        self.assertEqual(decoded_func(decoded_args[0]), 12)
        self.assertEqual(decoded_kwargs, {"unused": None})

    def test_headers_distinguish_callable_and_data(self):
        self.assertTrue(serialize(make_adder(1)).startswith(b"C2\n"))
        self.assertTrue(serialize((1, 2)).startswith(b"02\n"))

    def test_unserializable_argument_fails_before_message_pack(self):
        with self.assertRaises(RuntimeError):
            pack_apply_message(make_adder(1), (Unserializable(),), {})

    def test_closure_captures_snapshot_at_serialization_time(self):
        captured = {"value": 3}

        def read_captured():
            return captured["value"]

        packed = pack_apply_message(read_captured, (), {})
        captured["value"] = 99
        decoded_func, _, _ = unpack_apply_message(packed)

        self.assertEqual(decoded_func(), 3)

    def test_nested_argument_graph_round_trips(self):
        nested = {"outer": [1, {"inner": (2, 3)}]}
        packed = pack_apply_message(lambda value: value, (nested,), {})
        decoded_func, decoded_args, _ = unpack_apply_message(packed)

        self.assertEqual(decoded_func(decoded_args[0]), nested)


if __name__ == "__main__":
    unittest.main()
