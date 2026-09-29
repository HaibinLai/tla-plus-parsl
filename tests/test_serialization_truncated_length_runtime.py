"""Runtime probe for declared-length validation in the framing layer."""

import unittest
from unittest import mock

from parsl.serialize import facade


class SerializationTruncatedLengthRuntimeTest(unittest.TestCase):
    def test_short_payload_reaches_deserializer_before_frame_count_assertion(self):
        decoded = []

        def fake_deserialize(payload):
            decoded.append(payload)
            return "decoded"

        # The frame declares five bytes but only carries three. The current
        # slicer passes those three bytes onward and only later rejects the
        # one-frame apply message.
        with mock.patch.object(facade, "deserialize", side_effect=fake_deserialize):
            with self.assertRaises(AssertionError):
                facade.unpack_and_deserialize(b"5\nabc")

        self.assertEqual(decoded, [b"abc"])


if __name__ == "__main__":
    unittest.main()
