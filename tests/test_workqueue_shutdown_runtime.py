"""Runtime probe for WorkQueue collector shutdown finalization."""

import threading
import unittest
from concurrent.futures import Future

from parsl.executors.workqueue.errors import WorkQueueFailure
from parsl.executors.workqueue.executor import WorkQueueExecutor


class WorkQueueShutdownRuntimeTest(unittest.TestCase):
    def test_collector_exit_fails_outstanding_future(self):
        class StopFlag:
            value = True

        executor = WorkQueueExecutor.__new__(WorkQueueExecutor)
        executor.should_stop = StopFlag()
        executor.tasks_lock = threading.Lock()
        future = Future()
        executor._tasks = {7: future}

        executor._collect_work_queue_results()

        with self.assertRaises(WorkQueueFailure):
            future.result()


if __name__ == "__main__":
    unittest.main()
