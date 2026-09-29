"""Runtime probe for failed dynamic deserializer cache entries."""

import unittest
from unittest.mock import patch

from parsl.serialize import facade


class FailingDeserializer:
    instances = 0

    def __init__(self):
        type(self).instances += 1

    def deserialize(self, payload):
        raise ValueError("plugin decode failed")


class SerializationPluginFailureCacheRuntimeTest(unittest.TestCase):
    def test_failed_plugin_decode_remains_cached_currently(self):
        header = b"failure_plugin FailingDeserializer"
        facade.additional_methods_for_deserialization.pop(header, None)
        FailingDeserializer.instances = 0

        Module = type("Module", (), {"FailingDeserializer": FailingDeserializer})

        with patch.object(facade.importlib, "import_module", return_value=Module):
            with self.assertRaises(ValueError):
                facade.deserialize(header + b"\npayload")

        self.assertIn(header, facade.additional_methods_for_deserialization)
        self.assertEqual(FailingDeserializer.instances, 1)
        facade.additional_methods_for_deserialization.pop(header, None)


if __name__ == "__main__":
    unittest.main()
