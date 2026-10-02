"""Runtime probe for Radical-Pilot serialization error normalization."""

import unittest
from unittest.mock import patch

from parsl.executors.radical import executor as radical_executor


class RadicalSerializationFailureRuntimeTest(unittest.TestCase):
    def test_non_type_serializer_failure_escapes_currently(self):
        executor = radical_executor.RadicalPilotExecutor.__new__(
            radical_executor.RadicalPilotExecutor
        )
        with patch.object(
            radical_executor,
            "pack_apply_message",
            side_effect=ValueError("serializer failed"),
        ):
            with self.assertRaises(ValueError):
                executor._pack_and_apply_message(lambda: None, (), {})


if __name__ == "__main__":
    unittest.main()
