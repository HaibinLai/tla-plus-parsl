"""Runtime probe for non-numeric HTEX task priority."""

import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class FakeTaskSocket:
    def recv_pyobj(self):
        return {"task_id": 7, "context": {"resource_spec": {"priority": "high"}}}


class HtexTaskPriorityTypeRuntimeTest(unittest.TestCase):
    def test_non_numeric_priority_currently_escapes_task_processing(self):
        interchange = Interchange.__new__(Interchange)
        interchange.task_incoming = FakeTaskSocket()
        interchange.socks = {interchange.task_incoming: zmq.POLLIN}

        with self.assertRaises(TypeError):
            interchange.process_task_incoming()


if __name__ == "__main__":
    unittest.main()
