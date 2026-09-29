"""Runtime probe for wall-clock rollback in the resource monitor."""

import collections
import sys
import types
import unittest
from unittest import mock

from parsl.monitoring import remote


class _FakeProcess:
    def __init__(self):
        self._running = iter([True, True, False])

    def is_running(self):
        return next(self._running)

    def as_dict(self):
        return {
            "cpu_num": 0,
            "create_time": 0.0,
            "cwd": "/tmp",
            "exe": "/bin/true",
            "memory_percent": 1.0,
            "nice": 0,
            "name": "fake",
            "num_threads": 1,
            "pid": 1,
            "ppid": 0,
            "status": "running",
            "username": "tester",
        }

    def children(self, recursive=True):
        return []

    def cpu_num(self):
        return 0

    def num_ctx_switches(self):
        return collections.namedtuple("ctx", "voluntary involuntary")(0, 0)

    def memory_info(self):
        return collections.namedtuple("mem", "vms rss")(1, 1)

    def cpu_times(self):
        return collections.namedtuple("cpu", "user system")(0.0, 0.0)

    def io_counters(self):
        return collections.namedtuple("io", "write_chars read_chars")(0, 0)


class _FakeEvent:
    def is_set(self):
        return False

    def wait(self, timeout):
        return False


class _FakeRadio:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class _FakeRadioConfig:
    def __init__(self, radio):
        self.radio = radio

    def create_sender(self):
        return self.radio


class ResourceMonitorClockRuntimeTest(unittest.TestCase):
    def test_wall_clock_rollback_suppresses_due_intermediate_sample_currently(self):
        fake_psutil = types.SimpleNamespace(
            Process=lambda pid: _FakeProcess(),
            cpu_count=lambda: 1,
        )
        radio = _FakeRadio()
        # initial next_send=100; first sample is sent, then the wall clock
        # rolls back before the next sample's due time of 110.
        clock = iter([100.0, 100.0, 99.0, 99.5, 99.5])
        with mock.patch.dict(sys.modules, {"psutil": fake_psutil}), \
                mock.patch.object(remote.time, "time", side_effect=clock), \
                mock.patch("parsl.utils.setproctitle"):
            remote.monitor(1, 0, 0, _FakeRadioConfig(radio), "run", 0, 10.0, ".", _FakeEvent())

        # One intermediate message plus the unconditional final message: the
        # second intermediate sample was suppressed by the rollback.
        self.assertEqual(len(radio.messages), 2)


if __name__ == "__main__":
    unittest.main()
