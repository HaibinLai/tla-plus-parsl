"""Runtime bridge for serialized callable snapshots across duplicate ZMQ envelopes."""

import unittest

from parsl.serialize import deserialize, serialize


class ZmqSerializedAckRuntimeTest(unittest.TestCase):
    def test_serialized_snapshot_survives_source_mutation_and_duplicate_delivery(self):
        source = {"value": 1}

        def task():
            return source["value"]

        envelope = {"task_id": "t-1", "attempt": 0, "payload": serialize(task)}
        source["value"] = 2

        first = deserialize(envelope["payload"])
        duplicate = deserialize(envelope["payload"])
        self.assertEqual(first(), 1)
        self.assertEqual(duplicate(), 1)

        seen = set()
        dispatches = []
        for received in (envelope, envelope.copy()):
            identity = (received["task_id"], received["attempt"])
            if identity not in seen:
                seen.add(identity)
                dispatches.append(deserialize(received["payload"])())

        self.assertEqual(dispatches, [1])
        self.assertEqual(len(seen), 1)


if __name__ == "__main__":
    unittest.main()
