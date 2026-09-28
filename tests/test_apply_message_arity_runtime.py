"""Runtime probe for apply-message unpacker arity validation."""

import unittest

from parsl.serialize.facade import pack_buffers, serialize, unpack_apply_message


class ApplyMessageArityRuntimeTest(unittest.TestCase):
    def test_extra_frame_is_returned_by_public_unpacker_currently(self):
        packed = pack_buffers([serialize("func"), serialize("args"),
                               serialize("kwargs"), serialize("extra")])
        self.assertEqual(unpack_apply_message(packed), ["func", "args", "kwargs", "extra"])


if __name__ == "__main__":
    unittest.main()
