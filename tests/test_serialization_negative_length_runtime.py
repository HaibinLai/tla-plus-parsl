"""Runtime probe for negative serialization-frame lengths."""

import unittest

from parsl.serialize.facade import unpack_buffers


class SerializationNegativeLengthRuntimeTest(unittest.TestCase):
    def test_negative_length_crashes_after_a_partial_slice_currently(self):
        # The first slice uses -1 as a Python endpoint, then the leftover byte
        # is parsed as a new frame and raises because it has no newline.
        with self.assertRaises(ValueError):
            unpack_buffers(b"-1\nabc")


if __name__ == "__main__":
    unittest.main()
