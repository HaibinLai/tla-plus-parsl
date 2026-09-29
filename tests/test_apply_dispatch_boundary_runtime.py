"""Runtime bridge for facade unpacking versus worker invocation arity."""

import unittest

from parsl.executors.execute_task import execute_task
from parsl.serialize.facade import pack_apply_message, pack_buffers, serialize, unpack_apply_message


def add_one(value):
    return value + 1


class ApplyDispatchBoundaryRuntimeTest(unittest.TestCase):
    def test_facade_returns_extra_frame_but_worker_rejects_it(self):
        payload = pack_apply_message(add_one, (41,), {})
        malformed = payload + pack_buffers([serialize("unexpected")])

        unpacked = unpack_apply_message(malformed)
        self.assertEqual(len(unpacked), 4)
        with self.assertRaises(ValueError):
            execute_task(malformed)


if __name__ == "__main__":
    unittest.main()
