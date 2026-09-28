"""Runtime probe for mutable callable state and the dill serializer cache."""

import unittest

from parsl.serialize.concretes import DillCallableSerializer


class MutableCallable:
    def __init__(self, value):
        self.value = value

    def __call__(self):
        return self.value


class CallableMutationCacheRuntimeTest(unittest.TestCase):
    def test_cached_callable_payload_preserves_old_mutable_state(self):
        serializer = DillCallableSerializer()
        callable_obj = MutableCallable(1)

        first = serializer.serialize(callable_obj)
        callable_obj.value = 2
        second = serializer.serialize(callable_obj)

        self.assertEqual(first, second)
        self.assertEqual(serializer.deserialize(second)(), 1)
        self.assertEqual(callable_obj(), 2)


if __name__ == "__main__":
    unittest.main()
