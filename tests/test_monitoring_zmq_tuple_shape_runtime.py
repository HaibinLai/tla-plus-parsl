"""Runtime bridge for MonitoringRouter tuple-shape admission."""

import unittest

from parsl.monitoring.radios.zmq_router import MonitoringRouter


class FakeExitEvent:
    def __init__(self, checks_before_exit):
        self.checks = 0
        self.checks_before_exit = checks_before_exit

    def is_set(self):
        self.checks += 1
        return self.checks > self.checks_before_exit


class FakeReceiver:
    def __init__(self, messages):
        self.messages = iter(messages)

    def recv_pyobj(self):
        return next(self.messages)


class FakeTargetRadio:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class MonitoringZMQTupleShapeRuntimeTest(unittest.TestCase):
    def make_router(self, messages):
        router = MonitoringRouter.__new__(MonitoringRouter)
        router.exit_event = FakeExitEvent(checks_before_exit=2)
        router.zmq_receiver_channel = FakeReceiver(messages)
        router.target_radio = FakeTargetRadio()
        return router

    def test_malformed_tuple_is_discarded_and_valid_tuple_is_forwarded(self):
        valid = ("resource", {"value": 3})
        router = self.make_router([("malformed",), valid])

        router.start()

        self.assertEqual(router.target_radio.messages, [valid])


if __name__ == "__main__":
    unittest.main()
