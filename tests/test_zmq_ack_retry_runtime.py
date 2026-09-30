"""Runtime bridge for duplicate ZMQ envelope delivery and receiver deduplication."""

import unittest

import zmq

from parsl.serialize.facade import pack_apply_message, unpack_apply_message


def increment(value):
    return value + 1


class ZmqAckRetryRuntimeTest(unittest.TestCase):
    def test_retransmitted_serialized_envelope_is_dispatched_once(self):
        context = zmq.Context()
        router = context.socket(zmq.ROUTER)
        dealer = context.socket(zmq.DEALER)
        try:
            endpoint = "inproc://parsl-tla-ack-retry"
            router.bind(endpoint)
            dealer.setsockopt(zmq.IDENTITY, b"executor-1")
            dealer.connect(endpoint)

            task_id = b"task-7"
            payload = pack_apply_message(increment, (41,), {})
            dealer.send_multipart([task_id, payload])
            dealer.send_multipart([task_id, payload])

            received = []
            for _ in range(2):
                self.assertTrue(router.poll(1000, zmq.POLLIN))
                frames = router.recv_multipart()
                self.assertEqual(frames[0], b"executor-1")
                received.append((frames[1], frames[2]))

            self.assertEqual(received, [(task_id, payload), (task_id, payload)])

            seen = set()
            results = []
            for message_id, packed in received:
                if message_id in seen:
                    continue
                seen.add(message_id)
                func, args, kwargs = unpack_apply_message(packed)
                results.append(func(*args, **kwargs))

            self.assertEqual(results, [42])
            self.assertEqual(seen, {task_id})
        finally:
            router.close(0)
            dealer.close(0)
            context.term()


if __name__ == "__main__":
    unittest.main()
