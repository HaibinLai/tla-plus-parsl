"""Runtime bridge for the join/ZMQ/retry composition."""

import unittest

from parsl.serialize import deserialize, serialize


class JoinZmqRetryRuntimeTest(unittest.TestCase):
    def test_task_payload_keeps_submit_snapshot_across_object_mutation(self):
        captured = {"version": 0, "items": ["a"]}
        envelope = {
            "task_id": "inner-a",
            "attempt": 0,
            "payload": serialize(captured),
        }

        captured["version"] = 1
        captured["items"].append("late")

        decoded = deserialize(envelope["payload"])
        self.assertEqual(decoded, {"version": 0, "items": ["a"]})
        self.assertEqual((envelope["task_id"], envelope["attempt"]), ("inner-a", 0))

    def test_join_result_accepts_current_attempt_once_and_rejects_late_old_result(self):
        messages = [
            {"task_id": "inner-a", "attempt": 0, "payload": serialize({"value": "old"})},
            {"task_id": "inner-a", "attempt": 1, "payload": serialize({"value": "new"})},
            {"task_id": "inner-a", "attempt": 1, "payload": serialize({"value": "new"})},
        ]
        current = {"inner-a": 1}
        seen = set()
        accepted = []
        for message in messages:
            identity = (message["task_id"], message["attempt"])
            if identity[1] != current[identity[0]] or identity in seen:
                continue
            seen.add(identity)
            accepted.append(deserialize(message["payload"])["value"])

        self.assertEqual(accepted, ["new"])
        self.assertEqual(seen, {("inner-a", 1)})


if __name__ == "__main__":
    unittest.main()
