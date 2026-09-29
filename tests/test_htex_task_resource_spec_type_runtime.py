"""Runtime probe for a non-mapping HTEX resource specification."""

import unittest

import zmq

from parsl.executors.high_throughput.interchange import Interchange


class FakeTaskSocket:
    def recv_pyobj(self):
        return {"task_id": 7, "context": {"resource_spec": ["cores", 1]}}


class HtexTaskResourceSpecTypeRuntimeTest(unittest.TestCase):
    def test_non_mapping_resource_spec_currently_escapes_task_processing(self):
        interchange = Interchange.__new__(Interchange)
        interchange.task_incoming = FakeTaskSocket()
        interchange.socks = {interchange.task_incoming: zmq.POLLIN}

        with self.assertRaises(AttributeError):
            interchange.process_task_incoming()


if __name__ == "__main__":
    unittest.main()
