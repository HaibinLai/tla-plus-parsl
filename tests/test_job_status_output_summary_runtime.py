"""Runtime probes for JobStatus output and summary handling."""

import tempfile
import unittest
from pathlib import Path

from parsl.jobs.states import JobState, JobStatus


class JobStatusOutputSummaryRuntimeTest(unittest.TestCase):
    def test_summary_keeps_exact_threshold_file_in_full(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "stdout"
            content = "a" * 1024 + "b" * 1024
            path.write_text(content)
            status = JobStatus(JobState.COMPLETED, stdout_path=str(path))
            self.assertEqual(status.stdout, content)
            self.assertEqual(status.stdout_summary, content)

    def test_summary_truncates_large_file_while_preserving_edges(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "stdout"
            content = "a" * 1024 + "middle" + "b" * 1024
            path.write_text(content)
            summary = JobStatus(JobState.FAILED, stdout_path=str(path)).stdout_summary
            self.assertEqual(summary, "a" * 1024 + "\n...\n" + "b" * 1024)
            self.assertNotIn("middle", summary)

    def test_missing_output_file_returns_none(self):
        status = JobStatus(JobState.FAILED, stdout_path="/definitely/missing/parsl.stdout")
        self.assertIsNone(status.stdout)
        self.assertIsNone(status.stdout_summary)


if __name__ == "__main__":
    unittest.main()
