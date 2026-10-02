"""Runtime bridge for retry projection results over serialized ZMQ frames."""

import pickle
import unittest

import parsl
import zmq
from parsl import Config, python_app
from parsl.executors.threads import ThreadPoolExecutor
from parsl.serialize import deserialize, serialize
from parsl.executors.flux import TaskResult


attempts = {"count": 0}


@python_app
def zmq_retry_projection_source():
    attempts["count"] += 1
    if attempts["count"] == 1:
        raise RuntimeError("first physical attempt")
    return {"value": "wire-ready"}


class FutureProjectionRetryZMQRuntimeTest(unittest.TestCase):
    def test_projection_result_uses_current_serialized_attempt(self):
        attempts["count"] = 0
        config = Config(executors=[ThreadPoolExecutor(max_threads=2)], retries=1)
        with parsl.load(config):
            projected = zmq_retry_projection_source()["value"]
            self.assertEqual(projected.result(), "wire-ready")
        self.assertEqual(attempts["count"], 2)

        context = zmq.Context()
        sender = context.socket(zmq.PAIR)
        receiver = context.socket(zmq.PAIR)
        endpoint = "inproc://parsl-projection-retry-zmq"
        receiver.bind(endpoint)
        sender.connect(endpoint)
        try:
            for attempt, value in ((0, "old"), (1, "current"), (1, "current")):
                envelope = {
                    "task_id": 17,
                    "attempt": attempt,
                    "payload": serialize(TaskResult(value, None)),
                }
                sender.send(pickle.dumps(envelope))

            accepted = None
            seen = set()
            for _ in range(3):
                envelope = pickle.loads(receiver.recv())
                identity = (envelope["task_id"], envelope["attempt"])
                if identity != (17, 1) or identity in seen:
                    continue
                seen.add(identity)
                accepted = deserialize(envelope["payload"]).returnval
            self.assertEqual(accepted, "current")
        finally:
            sender.close(0)
            receiver.close(0)
            context.term()


if __name__ == "__main__":
    unittest.main()
