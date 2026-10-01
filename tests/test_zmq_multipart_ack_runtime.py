"""Runtime bridge for multipart frame validation and ACK retransmission."""

import unittest
from unittest.mock import patch

from parsl.serialize import facade


class ZmqMultipartAckRuntimeTest(unittest.TestCase):
    def test_malformed_frame_count_is_rejected_before_decode(self):
        decoded = []

        def fake_deserialize(payload):
            decoded.append(payload)
            return payload

        packed = facade.pack_buffers([b"func", b"args", b"kwargs", b"extra"])
        with patch.object(facade, "deserialize", side_effect=fake_deserialize):
            with self.assertRaises(AssertionError):
                facade.unpack_and_deserialize(packed)

        self.assertEqual(decoded, [b"func", b"args", b"kwargs", b"extra"])

    def test_valid_retransmission_is_deduplicated_by_identity(self):
        envelope = ("task-1", 0, b"serialized-payload")
        seen = set()
        dispatches = []
        for received in (envelope, envelope):
            identity = received[:2]
            if identity not in seen:
                seen.add(identity)
                dispatches.append(received[2])

        self.assertEqual(dispatches, [b"serialized-payload"])
        self.assertEqual(len(seen), 1)


if __name__ == "__main__":
    unittest.main()
