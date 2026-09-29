"""Runtime probe for block provisioning failure monitoring."""

import unittest

from parsl.executors.status_handling import BlockProviderExecutor


class FailingProvider:
    def submit(self, command, tasks_per_node, job_name):
        raise RuntimeError("provider rejected allocation")


class RecordingRadio:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)


class DummyBlockExecutor(BlockProviderExecutor):
    def __init__(self):
        super().__init__(provider=FailingProvider(), block_error_handler=False)
        self.submit_monitoring_radio = RecordingRadio()

    def outstanding(self):
        return 0

    def _get_launch_command(self, block_id):
        return "launch"

    def submit(self, *args, **kwargs):
        raise NotImplementedError

    def shutdown(self):
        pass

    @property
    def workers_per_node(self):
        return 1


class ScaleOutFailureMonitoringRuntimeTest(unittest.TestCase):
    def test_failed_provisioning_is_stored_but_not_reported(self):
        executor = DummyBlockExecutor()

        self.assertEqual(executor.scale_out_facade(1), [])
        self.assertEqual(executor._status["0"].status_name, "FAILED")
        self.assertEqual(len(executor.submit_monitoring_radio.messages), 1)
        # The radio is notified, but its BLOCK_INFO payload omits the failed block.
        self.assertEqual(executor.submit_monitoring_radio.messages[0][1], [])


if __name__ == "__main__":
    unittest.main()
