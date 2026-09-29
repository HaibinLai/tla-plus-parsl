"""Runtime bridge for callable snapshots on retry attempts."""

import unittest

from parsl.serialize.facade import pack_apply_message, unpack_apply_message


def make_increment(box):
    def increment(value):
        return value + box["offset"]

    return increment


class CallableRetryTransportRuntimeTest(unittest.TestCase):
    def test_each_attempt_captures_its_own_callable_content(self):
        box = {"offset": 1}
        first_payload = pack_apply_message(make_increment(box), (10,), {})

        # A retry is a new physical attempt and serializes the new closure
        # contents instead of reusing the old task bytes.
        box["offset"] = 2
        second_payload = pack_apply_message(make_increment(box), (10,), {})

        first_func, first_args, first_kwargs = unpack_apply_message(first_payload)
        second_func, second_args, second_kwargs = unpack_apply_message(second_payload)
        self.assertEqual(first_func(*first_args, **first_kwargs), 11)
        self.assertEqual(second_func(*second_args, **second_kwargs), 12)

        current_attempt = 1
        delivered = {0: first_func(*first_args, **first_kwargs),
                     1: second_func(*second_args, **second_kwargs)}
        accepted = delivered[current_attempt]
        self.assertEqual(accepted, 12)


if __name__ == "__main__":
    unittest.main()
