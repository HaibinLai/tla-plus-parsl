"""Runtime probe for equal-but-distinct callable serializer cache keys."""

import unittest

from parsl.serialize.concretes import DillCallableSerializer


class EqualCallable:
    def __init__(self, value):
        self.value = value

    def __call__(self):
        return self.value

    def __eq__(self, other):
        return isinstance(other, EqualCallable)

    def __hash__(self):
        return 1


class CallableEqualCacheRuntimeTest(unittest.TestCase):
    def test_equal_distinct_callable_reuses_first_payload_currently(self):
        serializer = DillCallableSerializer()
        serializer.serialize.cache_clear()
        serializer.deserialize.cache_clear()

        first = EqualCallable("A")
        second = EqualCallable("B")
        serializer.serialize(first)
        second_payload = serializer.serialize(second)

        decoded = serializer.deserialize(second_payload)
        self.assertEqual(decoded(), "A")


if __name__ == "__main__":
    unittest.main()
