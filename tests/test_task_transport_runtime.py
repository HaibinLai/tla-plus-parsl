"""Runtime probe for the combined Python-serialization and ZMQ task path."""

import unittest

import zmq

from parsl.serialize.facade import pack_apply_message, unpack_apply_message


def make_adder(offset):
    def add(value):
        return value + offset

    return add


class TaskTransportRuntimeTest(unittest.TestCase):
    def test_real_serialized_task_crosses_zmq_and_executes(self):
        context = zmq.Context()
        sender = context.socket(zmq.PAIR)
        receiver = context.socket(zmq.PAIR)
        endpoint = "inproc://parsl-task-transport-runtime"
        try:
            receiver.bind(endpoint)
            sender.connect(endpoint)

            payload = pack_apply_message(make_adder(7), (5,), {})
            sender.send(payload)

            decoded_func, decoded_args, decoded_kwargs = unpack_apply_message(receiver.recv())
            self.assertEqual(decoded_kwargs, {})
            self.assertEqual(decoded_func(*decoded_args, **decoded_kwargs), 12)
        finally:
            sender.close(0)
            receiver.close(0)
            context.term()


if __name__ == "__main__":
    unittest.main()
