"""Runtime probe for callable and argument content snapshots."""

import unittest

from parsl.serialize.facade import pack_apply_message, unpack_apply_message


def make_adder(box):
    def add(value):
        return box["offset"] + value

    return add


class FunctionObjectContentsRuntimeTest(unittest.TestCase):
    def test_wire_payload_keeps_function_and_argument_snapshot(self):
        box = {"offset": 1}
        function = make_adder(box)
        payload = pack_apply_message(function, (4,), {})
        box["offset"] = 10

        decoded_function, args, kwargs = unpack_apply_message(payload)

        self.assertEqual(decoded_function(*args, **kwargs), 5)
        self.assertEqual(args, (4,))

    def test_function_and_keyword_object_use_the_same_submit_time_content(self):
        box = {"offset": 1, "bias": 1}

        def combine(value, meta):
            return box["offset"] + value + meta["bias"]

        payload = pack_apply_message(combine, (4,), {"meta": box})
        box["offset"] = 10
        box["bias"] = 20

        decoded_function, args, kwargs = unpack_apply_message(payload)
        self.assertEqual(decoded_function(*args, **kwargs), 6)
        self.assertEqual(kwargs["meta"], {"offset": 1, "bias": 1})


if __name__ == "__main__":
    unittest.main()
