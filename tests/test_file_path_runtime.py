"""Runtime probes for File.filepath scheme and local_path resolution."""

import unittest

from parsl.data_provider.files import File


class FilePathRuntimeTest(unittest.TestCase):
    def test_local_file_url_resolves_without_annotation(self):
        file_obj = File("file:///input")
        self.assertEqual(file_obj.filepath, "/input")

    def test_local_path_overrides_global_url(self):
        file_obj = File("https://example.invalid/input")
        file_obj.local_path = "/worker/input"
        self.assertEqual(file_obj.filepath, "/worker/input")

    def test_remote_url_without_local_path_is_rejected(self):
        file_obj = File("https://example.invalid/input")
        with self.assertRaises(ValueError):
            _ = file_obj.filepath


if __name__ == "__main__":
    unittest.main()
