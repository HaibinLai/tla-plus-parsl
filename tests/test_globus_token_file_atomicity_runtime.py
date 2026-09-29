"""Runtime probe for atomic Globus token-file publication."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from parsl.data_provider.globus import Globus


class GlobusTokenFileAtomicityRuntimeTest(unittest.TestCase):
    def test_json_failure_truncates_existing_token_file_currently(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tokens.json"
            path.write_text('{"refresh_token": "old"}')

            with patch("parsl.data_provider.globus.json.dump", side_effect=RuntimeError("encode failed")):
                with self.assertRaises(RuntimeError):
                    Globus._save_tokens_to_file(str(path), {"refresh_token": "new"})

            self.assertEqual(path.read_text(), "")


if __name__ == "__main__":
    unittest.main()
