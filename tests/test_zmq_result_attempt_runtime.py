"""Runtime bridge for serialized result attempts and stale-result filtering."""

import pickle
import unittest

import zmq

from parsl.executors.flux import TaskResult
from parsl.serialize import deserialize, serialize


class ZmqResultAttemptRuntimeTest(unittest.TestCase):
    def test_task_result_round_trip_keeps_attempt_identity_outside_payload(self):
        payload = serialize(TaskResult("fresh", None))
        envelope = {"task_id": "task-1", "attempt": 1, "payload": payload}

        decoded = deserialize(envelope["payload"])
        self.assertEqual(decoded.returnval, "fresh")
        self.assertEqual(decoded.exception, None)
        self.assertEqual((envelope["task_id"], envelope["attempt"]), ("task-1", 1))

    def test_late_old_attempt_and_duplicate_do_not_resolve_current_future(self):
        messages = [
            {"task_id": "task-1", "attempt": 0, "payload": serialize(TaskResult("old", None))},
            {"task_id": "task-1", "attempt": 1, "payload": serialize(TaskResult("new", None))},
            {"task_id": "task-1", "attempt": 1, "payload": serialize(TaskResult("new", None))},
        ]
        current_attempt = 1
        seen = set()
        results = []
        for message in messages:
            identity = (message["task_id"], message["attempt"])
            if identity != ("task-1", current_attempt) or identity in seen:
                continue
            seen.add(identity)
            results.append(deserialize(message["payload"]).returnval)

        self.assertEqual(results, ["new"])
        self.assertEqual(seen, {("task-1", 1)})

    def test_inproc_zmq_delivery_preserves_attempt_filtering(self):
        context = zmq.Context()
        sender = context.socket(zmq.PAIR)
        receiver = context.socket(zmq.PAIR)
        endpoint = "inproc://parsl-result-attempt-runtime"
        try:
            receiver.bind(endpoint)
            sender.connect(endpoint)
            messages = [
                {"task_id": "task-1", "attempt": 0,
                 "payload": serialize(TaskResult("old", None))},
                {"task_id": "task-1", "attempt": 1,
                 "payload": serialize(TaskResult("new", None))},
                {"task_id": "task-1", "attempt": 1,
                 "payload": serialize(TaskResult("new", None))},
            ]
            for message in messages:
                sender.send(pickle.dumps(message))

            current_attempt = 1
            seen = set()
            results = []
            for _ in messages:
                envelope = pickle.loads(receiver.recv())
                identity = (envelope["task_id"], envelope["attempt"])
                if identity != ("task-1", current_attempt) or identity in seen:
                    continue
                seen.add(identity)
                results.append(deserialize(envelope["payload"]).returnval)

            self.assertEqual(results, ["new"])
            self.assertEqual(seen, {("task-1", 1)})
        finally:
            sender.close(0)
            receiver.close(0)
            context.term()


if __name__ == "__main__":
    unittest.main()
