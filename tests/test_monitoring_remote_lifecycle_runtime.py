"""Runtime bridge for resource-monitor intermediate and final sends."""

import collections
import itertools
import sys
import types
import unittest
from unittest import mock

from parsl.monitoring import remote


class _Process:
    def __init__(self):
        self._running = iter([True, False])

    def is_running(self):
        return next(self._running)

    def as_dict(self):
        return {"cpu_num": 0, "create_time": 0.0, "cwd": "/tmp", "exe": "/bin/true",
                "memory_percent": 1.0, "nice": 0, "name": "fake", "num_threads": 1,
                "pid": 1, "ppid": 0, "status": "running", "username": "tester"}

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


class _Event:
    def is_set(self):
        return False

    def wait(self, timeout):
        return False


class _Radio:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class _RadioConfig:
    def __init__(self, radio):
        self.radio = radio

    def create_sender(self):
        return self.radio


class MonitoringRemoteLifecycleRuntimeTest(unittest.TestCase):
    def test_wall_clock_rollback_does_not_drop_unconditional_final_message(self):
        radio = _Radio()
        fake_psutil = types.SimpleNamespace(Process=lambda pid: _Process(), cpu_count=lambda: 1)
        clock = itertools.chain([100.0, 100.0, 99.0, 99.5, 99.5], itertools.repeat(99.5))
        with mock.patch.dict(sys.modules, {"psutil": fake_psutil}), \
                mock.patch.object(remote.time, "time", side_effect=clock), \
                mock.patch("parsl.utils.setproctitle"):
            remote.monitor(1, 0, 0, _RadioConfig(radio), "run", 0, 10.0, ".", _Event())

        self.assertEqual(len(radio.messages), 2)
        self.assertEqual(radio.messages[-1][0], remote.MessageType.RESOURCE_INFO)


if __name__ == "__main__":
    unittest.main()
