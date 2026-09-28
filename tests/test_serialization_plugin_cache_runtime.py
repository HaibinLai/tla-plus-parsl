"""Runtime probe for dynamic deserializer plugin caching."""

import types
import unittest
from unittest.mock import patch

from parsl.serialize import facade


class DynamicPlugin:
    instances = 0

    def __init__(self):
        type(self).instances += 1

    def deserialize(self, payload):
        return ("decoded", payload)


class SerializationPluginCacheRuntimeTest(unittest.TestCase):
    def test_dynamic_plugin_is_imported_once_and_then_cached(self):
        original = facade.additional_methods_for_deserialization.copy()
        DynamicPlugin.instances = 0
        try:
            facade.additional_methods_for_deserialization.clear()
            module = types.SimpleNamespace(DynamicPlugin=DynamicPlugin)
            with patch.object(facade.importlib, "import_module", return_value=module) as importer:
                first = facade.deserialize(b"fake_plugin DynamicPlugin\nfirst")
                second = facade.deserialize(b"fake_plugin DynamicPlugin\nsecond")

            self.assertEqual(first, ("decoded", b"first"))
            self.assertEqual(second, ("decoded", b"second"))
            self.assertEqual(importer.call_count, 1)
            self.assertEqual(DynamicPlugin.instances, 1)
            self.assertIn(b"fake_plugin DynamicPlugin",
                          facade.additional_methods_for_deserialization)
        finally:
            facade.additional_methods_for_deserialization.clear()
            facade.additional_methods_for_deserialization.update(original)


if __name__ == "__main__":
    unittest.main()
