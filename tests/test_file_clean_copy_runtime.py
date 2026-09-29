"""Runtime probe for File.cleancopy site-local metadata isolation."""

import unittest

from parsl.data_provider.files import File


class FileCleanCopyRuntimeTest(unittest.TestCase):
    def test_clean_copy_preserves_url_and_clears_local_path(self):
        original = File("https://source.example/input.bin")
        original.local_path = "/site-a/input.bin"

        copied = original.cleancopy()

        self.assertIsNot(copied, original)
        self.assertEqual(copied.url, original.url)
        self.assertIsNone(copied.local_path)
        self.assertEqual(original.local_path, "/site-a/input.bin")


if __name__ == "__main__":
    unittest.main()
