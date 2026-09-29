"""Runtime probe for an empty serializer registry."""

import unittest

from parsl.serialize import facade


class SerializationEmptyRegistryRuntimeTest(unittest.TestCase):
    def test_empty_data_registry_leaks_unbound_local_currently(self):
        original = facade.methods_for_data.copy()
        try:
            facade.methods_for_data.clear()
            with self.assertRaises(UnboundLocalError):
                facade.serialize({"value": 1})
        finally:
            facade.methods_for_data.clear()
            facade.methods_for_data.update(original)


if __name__ == "__main__":
    unittest.main()
