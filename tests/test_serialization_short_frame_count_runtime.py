"""Runtime probe for short apply-message frame validation."""

import unittest
from unittest.mock import patch

from parsl.serialize import facade


class SerializationShortFrameCountRuntimeTest(unittest.TestCase):
    def test_short_frame_message_deserializes_before_rejection_currently(self):
        decoded = []

        def fake_deserialize(payload):
            decoded.append(payload)
            return payload

        packed = facade.pack_buffers([b"func", b"args"])
        with patch.object(facade, "deserialize", side_effect=fake_deserialize):
            with self.assertRaises(AssertionError):
                facade.unpack_and_deserialize(packed)

        self.assertEqual(decoded, [b"func", b"args"])


if __name__ == "__main__":
    unittest.main()
