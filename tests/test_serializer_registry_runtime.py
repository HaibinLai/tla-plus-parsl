"""Runtime probe for facade serializer-registry dispatch precedence."""

import unittest

from parsl.serialize import facade


class _CodeSerializer:
    identifier = b"X"

    def deserialize(self, payload):
        return ("code", payload)


class _DataSerializer:
    identifier = b"X"

    def deserialize(self, payload):
        return ("data", payload)


class SerializerRegistryRuntimeTest(unittest.TestCase):
    def test_code_registry_wins_when_identifiers_collide(self):
        original_code = facade.methods_for_code.copy()
        original_data = facade.methods_for_data.copy()
        try:
            facade.methods_for_code.clear()
            facade.methods_for_data.clear()
            facade.methods_for_code[b"X"] = _CodeSerializer()
            facade.methods_for_data[b"X"] = _DataSerializer()
            self.assertEqual(facade.deserialize(b"X\npayload"), ("code", b"payload"))
        finally:
            facade.methods_for_code.clear()
            facade.methods_for_code.update(original_code)
            facade.methods_for_data.clear()
            facade.methods_for_data.update(original_data)


if __name__ == "__main__":
    unittest.main()
