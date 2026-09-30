"""Runtime probe for a syntactically valid but incomplete Globus token file."""

import sys
import types
import unittest
from unittest.mock import patch

from parsl.data_provider.globus import Globus


class GlobusTokenSchemaRuntimeTest(unittest.TestCase):
    def test_missing_transfer_service_record_raises_key_error_currently(self):
        with patch.object(Globus, "_load_tokens_from_file", return_value={"other.service": {}}):
            Globus.TOKEN_FILE = "/tmp/invalid-globus-token-schema.json"
            with patch.dict(sys.modules, {"globus_sdk": types.ModuleType("globus_sdk")}):
                with self.assertRaises(KeyError):
                    Globus._get_native_app_authorizer("test-client")


if __name__ == "__main__":
    unittest.main()
