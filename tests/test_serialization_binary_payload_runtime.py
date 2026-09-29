"""Runtime probe for binary bytes through Parsl serializer framing."""

import unittest

from parsl.serialize.facade import pack_buffers, unpack_buffers


class SerializationBinaryPayloadRuntimeTest(unittest.TestCase):
    def test_newline_nul_and_non_ascii_bytes_are_preserved(self):
        payload = b"a\n\x00\xff\x80b"
        packed = pack_buffers([payload, b""])

        self.assertEqual(unpack_buffers(packed), [payload, b""])


if __name__ == "__main__":
    unittest.main()
