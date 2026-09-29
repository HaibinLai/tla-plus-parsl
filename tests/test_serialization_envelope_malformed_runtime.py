"""Runtime probe for malformed serializer envelopes."""

import unittest

from parsl.serialize import deserialize


class SerializationEnvelopeMalformedRuntimeTest(unittest.TestCase):
    def test_payload_without_header_separator_raises_raw_value_error(self):
        with self.assertRaises(ValueError):
            deserialize(b"truncated-envelope")


if __name__ == "__main__":
    unittest.main()
