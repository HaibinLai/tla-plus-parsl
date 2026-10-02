"""Runtime bridge for poisoned deserializer cache across a retry."""

import unittest
from unittest.mock import patch

from parsl.serialize import facade


class FailingDeserializer:
    instances = 0

    def __init__(self):
        type(self).instances += 1

    def deserialize(self, payload):
        raise ValueError("plugin decode failed")


class PluginRetryMonitoringRuntimeTest(unittest.TestCase):
    def test_current_retry_reuses_poisoned_plugin_instance(self):
        header = b"retry_plugin FailingDeserializer"
        facade.additional_methods_for_deserialization.pop(header, None)
        FailingDeserializer.instances = 0
        module = type("Module", (), {"FailingDeserializer": FailingDeserializer})

        with patch.object(facade.importlib, "import_module", return_value=module):
            for _ in range(2):
                with self.assertRaises(ValueError):
                    facade.deserialize(header + b"\npayload")

        self.assertEqual(FailingDeserializer.instances, 1)
        self.assertIn(header, facade.additional_methods_for_deserialization)
        facade.additional_methods_for_deserialization.pop(header, None)

    def test_candidate_fixed_retry_evicts_before_reload(self):
        header = b"retry_plugin FailingDeserializer"
        facade.additional_methods_for_deserialization[header] = FailingDeserializer()
        facade.additional_methods_for_deserialization.pop(header, None)
        # The next retry can now load a fresh implementation instead of using
        # the failed cached object; this is the model's recovery boundary.
        self.assertNotIn(header, facade.additional_methods_for_deserialization)


if __name__ == "__main__":
    unittest.main()
