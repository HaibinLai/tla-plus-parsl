"""Runtime probes for the concrete ThreadPoolExecutor contract."""

import time
import unittest
import threading

from parsl.executors.errors import InvalidResourceSpecification
from parsl.executors.threads import ThreadPoolExecutor


class ThreadExecutorRuntimeTest(unittest.TestCase):
    def test_shutdown_waits_for_accepted_work_and_rejects_new_work(self):
        executor = ThreadPoolExecutor(max_threads=1)
        executor.start()
        future = executor.submit(lambda: (time.sleep(0.02), 7)[1], {})

        executor.shutdown(block=True)

        self.assertEqual(future.result(), 7)
        with self.assertRaises(RuntimeError):
            executor.submit(lambda: 8, {})

    def test_resource_specification_is_rejected(self):
        executor = ThreadPoolExecutor(max_threads=1)
        executor.start()
        try:
            with self.assertRaises(InvalidResourceSpecification):
                executor.submit(lambda: 1, {"cores": 1})
        finally:
            executor.shutdown(block=True)

    def test_nonblocking_shutdown_rejects_new_work_but_accepted_work_finishes(self):
        executor = ThreadPoolExecutor(max_threads=1)
        executor.start()
        release = threading.Event()
        future = executor.submit(lambda: (release.wait(1), 11)[1], {})

        executor.shutdown(block=False)

        with self.assertRaises(RuntimeError):
            executor.submit(lambda: 12, {})

        release.set()
        self.assertEqual(future.result(timeout=2), 11)


if __name__ == "__main__":
    unittest.main()
