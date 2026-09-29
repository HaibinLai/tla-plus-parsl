"""Runtime bridge for callable snapshots on retry attempts."""

import unittest
import pickle

import zmq

from parsl.serialize.facade import pack_apply_message, unpack_apply_message


def make_increment(box):
    def increment(value):
        return value + box["offset"]

    return increment


class CallableRetryTransportRuntimeTest(unittest.TestCase):
    def test_each_attempt_captures_its_own_callable_content(self):
        box = {"offset": 1}
        first_payload = pack_apply_message(make_increment(box), (10,), {})

        # A retry is a new physical attempt and serializes the new closure
        # contents instead of reusing the old task bytes.
        box["offset"] = 2
        second_payload = pack_apply_message(make_increment(box), (10,), {})

        first_func, first_args, first_kwargs = unpack_apply_message(first_payload)
        second_func, second_args, second_kwargs = unpack_apply_message(second_payload)
        self.assertEqual(first_func(*first_args, **first_kwargs), 11)
        self.assertEqual(second_func(*second_args, **second_kwargs), 12)

        current_attempt = 1
        delivered = {0: first_func(*first_args, **first_kwargs),
                     1: second_func(*second_args, **second_kwargs)}
        accepted = delivered[current_attempt]
        self.assertEqual(accepted, 12)

    def test_zmq_multipart_messages_preserve_attempt_correlation(self):
        box = {"offset": 1}
        first_payload = pack_apply_message(make_increment(box), (10,), {})
        box["offset"] = 2
        second_payload = pack_apply_message(make_increment(box), (10,), {})

        context = zmq.Context()
        router = context.socket(zmq.ROUTER)
        dealer = context.socket(zmq.DEALER)
        try:
            endpoint = "inproc://parsl-tla-callable-retry"
            router.bind(endpoint)
            dealer.setsockopt(zmq.IDENTITY, b"dfk")
            dealer.connect(endpoint)

            # Attempt 1 is sent first at the transport layer but attempt 0 is
            # deliberately delivered to the consumer as the late result.
            for attempt, payload in [(1, second_payload), (0, first_payload)]:
                dealer.send_multipart([
                    b"task",
                    pickle.dumps({"attempt": attempt, "payload": payload}),
                ])

            received = []
            for _ in range(2):
                self.assertTrue(router.poll(1000, zmq.POLLIN))
                frames = router.recv_multipart()
                envelope = pickle.loads(frames[2])
                function, args, kwargs = unpack_apply_message(envelope["payload"])
                received.append((envelope["attempt"], function(*args, **kwargs)))

            self.assertEqual(sorted(received), [(0, 11), (1, 12)])
            current_attempt = 1
            self.assertEqual(dict(received)[current_attempt], 12)
        finally:
            router.close(0)
            dealer.close(0)
            context.term()


if __name__ == "__main__":
    unittest.main()
