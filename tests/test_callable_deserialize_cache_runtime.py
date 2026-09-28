"""Runtime probe for callable deserialization cache aliasing."""

import unittest

from parsl.serialize.concretes import DillCallableSerializer


def callable_with_mutable_attribute(value):
    return value


class CallableDeserializeCacheRuntimeTest(unittest.TestCase):
    def test_repeated_decode_returns_mutated_cached_object_currently(self):
        serializer = DillCallableSerializer()
        payload = serializer.serialize(callable_with_mutable_attribute)

        first = serializer.deserialize(payload)
        first.marker = "changed-by-first-task"
        second = serializer.deserialize(payload)

        self.assertIs(first, second)
        self.assertEqual(second.marker, "changed-by-first-task")


if __name__ == "__main__":
    unittest.main()
