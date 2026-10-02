"""Runtime bridge for duplicate serialized ZMQ delivery and Future monitoring."""

import unittest
from concurrent.futures import Future

import zmq

from parsl.serialize.facade import pack_apply_message, unpack_apply_message


def add_one(value):
    return value + 1


class ZmqSerializedAckFutureMonitoringRuntimeTest(unittest.TestCase):
    def test_duplicate_envelope_resolves_future_and_monitor_once(self):
        context = zmq.Context()
        router = context.socket(zmq.ROUTER)
        dealer = context.socket(zmq.DEALER)
        try:
            endpoint = "inproc://parsl-tla-ack-future-monitoring"
            router.bind(endpoint)
            dealer.setsockopt(zmq.IDENTITY, b"executor-monitor")
            dealer.connect(endpoint)

            task_id = b"task-monitor-1"
            attempt = 0
            packed = pack_apply_message(add_one, (9,), {})
            dealer.send_multipart([task_id, str(attempt).encode(), packed])
            dealer.send_multipart([task_id, str(attempt).encode(), packed])

            future = Future()
            monitor_events = []
            seen = set()
            for _ in range(2):
                self.assertTrue(router.poll(1000, zmq.POLLIN))
                frames = router.recv_multipart()
                self.assertEqual(frames[0], b"executor-monitor")
                identity = (frames[1], frames[2])
                if identity in seen:
                    continue
                seen.add(identity)
                func, args, kwargs = unpack_apply_message(frames[3])
                result = func(*args, **kwargs)
                future.set_result(result)
                monitor_events.append((identity, "succeeded"))

            self.assertEqual(future.result(), 10)
            self.assertEqual(monitor_events, [((task_id, b"0"), "succeeded")])
            self.assertEqual(len(seen), 1)
        finally:
            router.close(0)
            dealer.close(0)
            context.term()


if __name__ == "__main__":
    unittest.main()
