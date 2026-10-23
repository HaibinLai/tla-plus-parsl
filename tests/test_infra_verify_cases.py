"""Regression checks for the evidence runner's TLC result classification."""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from infra.verify_cases import run_tlc


class FakeCompleted:
    def __init__(self, code: int, output: str):
        self.returncode = code
        self.stdout = output


class VerifyCasesTests(unittest.TestCase):
    def check(self, code: int, output: str, expected: str) -> dict:
        with tempfile.TemporaryDirectory() as temp:
            fake = Path(temp) / "fake"
            fake.touch()
            with patch("infra.verify_cases.subprocess.run", return_value=FakeCompleted(code, output)):
                return run_tlc(fake, fake, fake, fake, expected, "SendFailureSafety", 1)

    def test_nonzero_parse_error_is_not_a_counterexample(self):
        result = self.check(1, "Semantic error: unknown identifier", "counterexample")
        self.assertEqual(result["status"], "fail")

    def test_wrong_invariant_is_not_a_counterexample(self):
        output = "Error: Invariant TypeOK is violated.\nThe behavior up to this point is:"
        result = self.check(12, output, "counterexample")
        self.assertEqual(result["status"], "fail")

    def test_named_counterexample_passes(self):
        output = "Error: Invariant SendFailureSafety is violated.\nThe behavior up to this point is:"
        result = self.check(12, output, "counterexample")
        self.assertEqual(result["status"], "pass")

    def test_zero_exit_without_completion_is_not_fixed_success(self):
        result = self.check(0, "Starting...", "no_error")
        self.assertEqual(result["status"], "fail")


if __name__ == "__main__":
    unittest.main()
