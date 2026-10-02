"""Runtime probe for malformed callable/argument transport decoding."""

import unittest

from parsl.serialize.facade import unpack_apply_message


class FunctionDecodeFailureRuntimeTest(unittest.TestCase):
    def test_malformed_apply_message_is_rejected_before_future_admission(self):
        with self.assertRaises(ValueError):
            unpack_apply_message(b"bad")


if __name__ == "__main__":
    unittest.main()
