"""Runtime probe for callable-object hashing at Parsl's serializer cache."""

import unittest

import dill

from parsl.serialize.concretes import DillCallableSerializer, DillSerializer
from parsl.serialize.facade import serialize


class UnhashableCallable:
    def __eq__(self, other):
        return self is other

    def __call__(self, value):
        return value + 1


class CallableSerializerCacheRuntimeTest(unittest.TestCase):
    def test_unhashable_callable_fails_before_dill(self):
        function = UnhashableCallable()

        self.assertTrue(callable(function))
        self.assertIsNone(function.__hash__)
        self.assertEqual(dill.loads(DillSerializer().serialize(function))(4), 5)
        with self.assertRaises(TypeError):
            serialize(function)

    def test_hashable_function_uses_callable_serializer(self):
        def add_one(value):
            return value + 1

        payload = serialize(add_one)
        self.assertTrue(payload.startswith(b"C2\n"))
        decoded = DillCallableSerializer().deserialize(payload.split(b"\n", 1)[1])
        self.assertEqual(decoded(4), 5)


if __name__ == "__main__":
    unittest.main()
