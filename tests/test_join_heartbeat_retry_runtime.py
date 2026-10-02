"""Runtime bridge for join heartbeat expiry and attempt generation filtering."""

import unittest
from concurrent.futures import Future


class JoinHeartbeatRetryRuntimeTest(unittest.TestCase):
    def test_outer_join_waits_for_current_inner_attempt_after_heartbeat_loss(self):
        inner = {"a": [Future(), Future()], "b": [Future(), Future()]}
        current = {"a": 0, "b": 0}
        manager_alive = True
        outer = Future()
        values = {}

        def on_result(task, attempt, future):
            if attempt != current[task] or not manager_alive:
                return
            values[task] = future.result()
            if set(values) == set(inner):
                outer.set_result([values["a"], values["b"]])

        # The manager expires while both first attempts are in flight.
        manager_alive = False
        current["a"] = 1
        current["b"] = 1
        manager_alive = True  # provisioning restored a new manager
        inner["a"][0].set_result("late-a")
        on_result("a", 0, inner["a"][0])
        inner["b"][0].set_result("late-b")
        on_result("b", 0, inner["b"][0])
        self.assertFalse(outer.done())

        inner["a"][1].set_result("new-a")
        on_result("a", 1, inner["a"][1])
        self.assertFalse(outer.done())
        inner["b"][1].set_result("new-b")
        on_result("b", 1, inner["b"][1])

        self.assertEqual(outer.result(), ["new-a", "new-b"])


if __name__ == "__main__":
    unittest.main()
