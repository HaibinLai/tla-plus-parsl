"""Runtime probe for monitoring final-send exception masking."""

import unittest
from unittest import mock

from parsl.monitoring.remote import monitor_wrapper


class MonitoringWrapperCleanupRuntimeTest(unittest.TestCase):
    def test_final_monitoring_send_masks_body_error_currently(self):
        def failing_body(*args, **kwargs):
            raise ValueError("application failed")

        wrapped, args, kwargs = monitor_wrapper(
            f=failing_body,
            args=(),
            kwargs={},
            x_try_id=0,
            x_task_id=1,
            radio_config=mock.Mock(),
            run_id="run",
            logging_level=0,
            sleep_dur=0,
            monitor_resources=False,
            run_dir=".",
        )

        with mock.patch("parsl.monitoring.remote.send_first_message"), mock.patch(
            "parsl.monitoring.remote.send_last_message",
            side_effect=RuntimeError("final monitoring send failed"),
        ):
            with self.assertRaisesRegex(RuntimeError, "final monitoring send failed") as caught:
                wrapped(*args, **kwargs)

        self.assertIsInstance(caught.exception.__context__, ValueError)


if __name__ == "__main__":
    unittest.main()
