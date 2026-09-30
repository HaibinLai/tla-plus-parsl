"""Runtime bridge for serialized result-file publication."""

import tempfile
import unittest
from pathlib import Path

from parsl.executors.flux import TaskResult
from parsl.serialize import deserialize, serialize


class SerializedResultFileRuntimeTest(unittest.TestCase):
    def test_consumer_sees_complete_payload_only_after_atomic_publish(self):
        payload = serialize(TaskResult({"value": 42}, None))
        split = len(payload) // 2

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            visible = root / "result"
            temporary = root / "result.tmp"

            # A direct write exposes a partial serialized result to a reader.
            visible.write_bytes(payload[:split])
            with self.assertRaises(Exception):
                deserialize(visible.read_bytes())

            # The publication protocol writes privately, then atomically renames.
            temporary.write_bytes(payload)
            temporary.replace(visible)
            result = deserialize(visible.read_bytes())
            self.assertEqual(result.returnval, {"value": 42})
            self.assertIsNone(result.exception)


if __name__ == "__main__":
    unittest.main()
