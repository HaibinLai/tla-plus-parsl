"""Runtime probe for malformed zip staging paths."""

import unittest

from parsl.data_provider.files import File
from parsl.data_provider.zip import ZipFileStaging, zip_path_split


class ZipPathValidationRuntimeTest(unittest.TestCase):
    def test_scheme_only_zip_url_is_accepted_and_truncated_currently(self):
        file_obj = File("zip:/tmp/archive-without-separator")
        self.assertTrue(ZipFileStaging().is_zip_url(file_obj))

        zip_path, inside_path = zip_path_split(file_obj.path)
        self.assertNotEqual(zip_path, file_obj.path)
        self.assertNotIn(".zip/", file_obj.path)
        self.assertNotEqual(inside_path, "")


if __name__ == "__main__":
    unittest.main()
