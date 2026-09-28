"""Runtime probe for extra apply-message frames decoded before rejection."""

import unittest
from unittest.mock import patch

from parsl.serialize import facade


class SerializationFrameCountRuntimeTest(unittest.TestCase):
    def test_extra_frame_is_deserialized_before_assertion_currently(self):
        decoded = []

        def fake_deserialize(payload):
            decoded.append(payload)
            return payload

        packed = facade.pack_buffers([b"func", b"args", b"kwargs", b"extra"])
        with patch.object(facade, "deserialize", side_effect=fake_deserialize):
            with self.assertRaises(AssertionError):
                facade.unpack_and_deserialize(packed)

        self.assertEqual(decoded, [b"func", b"args", b"kwargs", b"extra"])


if __name__ == "__main__":
    unittest.main()
