"""Runtime probe for a real ZMQ multipart task envelope and Parsl payload."""

import unittest
from concurrent.futures import Future

import zmq

from parsl.serialize.facade import (
    pack_apply_message,
    unpack_apply_message,
    unpack_buffers,
)
from parsl.serialize import deserialize, serialize


def increment(value, label=None):
    return value + 1


class ZmqSerializationRuntimeTest(unittest.TestCase):
    def test_apply_message_has_three_length_prefixed_serializer_buffers(self):
        payload = pack_apply_message(increment, (41,), {"label": "wire"})
        buffers = unpack_buffers(payload)

        self.assertEqual(len(buffers), 3)
        self.assertTrue(buffers[0].startswith(b"C2\n"))
        self.assertTrue(buffers[1].startswith(b"02\n"))
        self.assertTrue(buffers[2].startswith(b"02\n"))
        # The public unpacker must decode the same three logical values in order.
        decoded_func, decoded_args, decoded_kwargs = unpack_apply_message(payload)
        self.assertEqual(decoded_func(*decoded_args, **decoded_kwargs), 42)
        self.assertEqual(decoded_kwargs, {"label": "wire"})

    def test_router_dealer_round_trip_preserves_route_and_payload(self):
        context = zmq.Context()
        router = context.socket(zmq.ROUTER)
        dealer = context.socket(zmq.DEALER)
        try:
            endpoint = "inproc://parsl-tla-zmq"
            router.bind(endpoint)
            dealer.setsockopt(zmq.IDENTITY, b"manager-1")
            dealer.connect(endpoint)

            payload = pack_apply_message(increment, (41,), {})
            dealer.send_multipart([b"task", payload])

            self.assertTrue(router.poll(1000, zmq.POLLIN))
            frames = router.recv_multipart()
            self.assertEqual(frames[0], b"manager-1")
            self.assertEqual(frames[1], b"task")
            decoded_func, decoded_args, decoded_kwargs = unpack_apply_message(frames[2])
            self.assertEqual(decoded_func(*decoded_args, **decoded_kwargs), 42)

            router.send_multipart([frames[0], b"ack"])
            self.assertTrue(dealer.poll(1000, zmq.POLLIN))
            self.assertEqual(dealer.recv_multipart(), [b"ack"])
        finally:
            router.close(0)
            dealer.close(0)
            context.term()

    def test_multipart_frame_count_is_explicit(self):
        context = zmq.Context()
        sender = context.socket(zmq.PAIR)
        receiver = context.socket(zmq.PAIR)
        try:
            endpoint = "inproc://parsl-tla-frame-count"
            sender.bind(endpoint)
            receiver.connect(endpoint)
            sender.send_multipart([b"header", b"body"])
            self.assertTrue(receiver.poll(1000, zmq.POLLIN))
            self.assertEqual(receiver.recv_multipart(), [b"header", b"body"])
        finally:
            sender.close(0)
            receiver.close(0)
            context.term()

    def test_four_task_multipart_delivery_preserves_task_identity(self):
        context = zmq.Context()
        sender = context.socket(zmq.PAIR)
        receiver = context.socket(zmq.PAIR)
        try:
            endpoint = "inproc://parsl-tla-four-task-correlation"
            sender.bind(endpoint)
            receiver.connect(endpoint)
            for task_id, value in reversed([(b"A", 1), (b"B", 2),
                                            (b"C", 3), (b"D", 4)]):
                sender.send_multipart([
                    task_id,
                    pack_apply_message(increment, (value,), {}),
                ])

            received = []
            for _ in range(4):
                self.assertTrue(receiver.poll(1000, zmq.POLLIN))
                task_id, payload = receiver.recv_multipart()
                func, args, kwargs = unpack_apply_message(payload)
                received.append((task_id, func(*args, **kwargs)))

            self.assertEqual(received, [(b"D", 5), (b"C", 4),
                                        (b"B", 3), (b"A", 2)])
        finally:
            sender.close(0)
            receiver.close(0)
            context.term()

    def test_result_attempt_correlation_rejects_late_serialized_frame(self):
        context = zmq.Context()
        sender = context.socket(zmq.PAIR)
        receiver = context.socket(zmq.PAIR)
        try:
            endpoint = "inproc://parsl-tla-result-attempt-correlation"
            sender.bind(endpoint)
            receiver.connect(endpoint)
            sender.send_multipart([b"task-1", b"0", serialize({"value": "old"})])
            sender.send_multipart([b"task-1", b"1", serialize({"value": "new"})])

            current_attempt = 1
            future = Future()
            accepted = set()
            for _ in range(2):
                self.assertTrue(receiver.poll(1000, zmq.POLLIN))
                task_id, attempt_bytes, payload = receiver.recv_multipart()
                identity = (task_id, int(attempt_bytes))
                if identity[1] != current_attempt or identity in accepted:
                    continue
                accepted.add(identity)
                future.set_result(deserialize(payload)["value"])

            self.assertEqual(future.result(), "new")
            self.assertEqual(accepted, {(b"task-1", 1)})
        finally:
            sender.close(0)
            receiver.close(0)
            context.term()


if __name__ == "__main__":
    unittest.main()
