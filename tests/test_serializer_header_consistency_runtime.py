"""Runtime probe for serializer-header/body consistency."""

import unittest

from parsl.serialize import deserialize, serialize


class SerializerHeaderConsistencyRuntimeTest(unittest.TestCase):
    def test_current_facade_accepts_swapped_data_header(self):
        payload = serialize({"value": 7})
        header, body = payload.split(b"\n", 1)

        self.assertEqual(header, b"02")
        swapped = b"C2\n" + body

        # Both built-in dill-based decoders currently accept this body.  The
        # protocol-level model still treats the envelope as inconsistent,
        # because its header no longer identifies the producing serializer.
        self.assertEqual(deserialize(swapped), {"value": 7})


if __name__ == "__main__":
    unittest.main()
