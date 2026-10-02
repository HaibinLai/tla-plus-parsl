"""Runtime bridge for the two-dependency join retry/stale-result model."""

import unittest
from concurrent.futures import Future


class JoinRetryStaleResultRuntimeTest(unittest.TestCase):
    def test_outer_join_ignores_late_attempt_and_waits_for_current_pair(self):
        attempts = {task: [Future(), Future()] for task in ("a", "b")}
        current = {"a": 0, "b": 0}
        outer = Future()
        accepted = {}

        def on_result(task, attempt):
            if attempt != current[task]:
                return
            accepted[task] = attempts[task][attempt].result()
            if set(accepted) == set(current):
                outer.set_result([accepted["a"], accepted["b"]])

        # Timeout/retry advances only the logical generation. The old
        # physical Future may still complete, but cannot resolve the join.
        current["a"] = 1
        current["b"] = 1
        attempts["a"][0].set_result("late-a")
        attempts["b"][0].set_result("late-b")
        on_result("a", 0)
        on_result("b", 0)
        self.assertFalse(outer.done())
        self.assertEqual(accepted, {})

        attempts["a"][1].set_result("fresh-a")
        on_result("a", 1)
        self.assertFalse(outer.done())
        attempts["b"][1].set_result("fresh-b")
        on_result("b", 1)

        self.assertEqual(outer.result(), ["fresh-a", "fresh-b"])


if __name__ == "__main__":
    unittest.main()
