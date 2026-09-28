"""Runtime probes for serializer fallback order in the facade."""

import unittest

from parsl.serialize import facade


class FakeSerializer:
    def __init__(self, identifier, payload=None, error=None):
        self.identifier = identifier
        self.payload = payload
        self.error = error

    def serialize(self, obj):
        if self.error is not None:
            raise self.error
        return self.payload

    def deserialize(self, payload):
        return payload


class SerializationFallbackRuntimeTest(unittest.TestCase):
    def run_with(self, serializers):
        original = facade.methods_for_data.copy()
        try:
            facade.methods_for_data.clear()
            for serializer in serializers:
                facade.methods_for_data[serializer.identifier] = serializer
            return facade.serialize({"value": 1})
        finally:
            facade.methods_for_data.clear()
            facade.methods_for_data.update(original)

    def test_failed_primary_falls_back_to_secondary(self):
        payload = b"secondary"
        result = self.run_with([
            FakeSerializer(b"P", error=ValueError("primary")),
            FakeSerializer(b"S", payload=payload),
        ])
        self.assertEqual(result, b"S\n" + payload)

    def test_all_failures_reraise_last_serializer_error(self):
        with self.assertRaises(RuntimeError) as context:
            self.run_with([
                FakeSerializer(b"P", error=ValueError("primary")),
                FakeSerializer(b"S", error=RuntimeError("secondary")),
            ])
        self.assertEqual(str(context.exception), "secondary")


if __name__ == "__main__":
    unittest.main()
