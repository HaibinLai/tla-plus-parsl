"""Runtime probe for CurveZMQ certificate-directory validation."""

import os
import tempfile
import unittest
from pathlib import Path

from parsl.curvezmq import _load_certificate, create_certificates


class CurveZMQCertificateRuntimeTest(unittest.TestCase):
    def test_private_directory_loads_and_public_directory_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            cert_dir = Path(create_certificates(directory))
            _load_certificate(cert_dir, "server")

            os.chmod(cert_dir, 0o755)
            with self.assertRaises(OSError):
                _load_certificate(cert_dir, "server")


if __name__ == "__main__":
    unittest.main()
