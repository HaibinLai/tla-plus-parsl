"""Runtime probe for the Globus staging-directory initialization race."""

import os
import unittest
from unittest.mock import patch

from parsl.data_provider.globus import Globus


class GlobusInitRaceRuntimeTest(unittest.TestCase):
    def test_directory_created_between_check_and_mkdir_raises_currently(self):
        Globus.authorizer = object()
        with patch.object(os.path, "isdir", return_value=False), \
                patch("parsl.data_provider.globus.os.mkdir", side_effect=FileExistsError):
            with self.assertRaises(FileExistsError):
                Globus.init()


if __name__ == "__main__":
    unittest.main()
