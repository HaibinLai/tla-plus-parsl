"""Runtime probe for invalid dynamically loaded serializer plugins."""

import unittest

from parsl.serialize.errors import DeserializerPluginError
from parsl.serialize.facade import deserialize


class SerializationPluginErrorRuntimeTest(unittest.TestCase):
    def test_importable_class_without_deserialize_leaks_attribute_error(self):
        # ``builtins.str`` imports and instantiates successfully, but is not a
        # serializer plugin and has no deserialize method.
        with self.assertRaises(AttributeError):
            deserialize(b"builtins str\npayload")

        # A malformed module/class header is wrapped by the existing facade;
        # this contrasts the unwrapped post-load interface failure above.
        with self.assertRaises(DeserializerPluginError):
            deserialize(b"not_a_real_module Missing\npayload")


if __name__ == "__main__":
    unittest.main()
