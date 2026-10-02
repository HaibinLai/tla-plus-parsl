import threading
import unittest

from parsl.executors.high_throughput.process_worker_pool import Manager


class _FakeSocket:
    def __init__(self, stop_event):
        self.stop_event = stop_event
        self.closed = False

    def setsockopt(self, *_args):
        return None

    def connect(self, _address):
        return None

    def send(self, _payload):
        self.stop_event.set()
        raise RuntimeError("interchange socket closed")

    def close(self):
        self.closed = True


class _FakeContext:
    def __init__(self, stop_event):
        self.stop_event = stop_event
        self.socket_instance = None

    def socket(self, _kind):
        self.socket_instance = _FakeSocket(self.stop_event)
        return self.socket_instance


class _OneResultScheduler:
    def __init__(self):
        self.result = {"type": "result", "task_id": "task-1"}
        self.consumed = False

    def get_result(self):
        if not self.consumed:
            self.consumed = True
            return self.result
        return None


class HtexFerryResultSendFailureRuntimeTest(unittest.TestCase):
    def test_send_failure_consumes_result_without_requeue_currently(self):
        manager = Manager.__new__(Manager)
        manager._stop_event = threading.Event()
        manager.zmq_context = _FakeContext(manager._stop_event)
        manager.task_scheduler = _OneResultScheduler()
        may_connect = threading.Event()
        may_connect.set()
        manager.ferry_result(may_connect)

        self.assertTrue(manager.task_scheduler.consumed)
        self.assertTrue(manager._stop_event.is_set())
        self.assertTrue(manager.zmq_context.socket_instance.closed)


if __name__ == "__main__":
    unittest.main()
