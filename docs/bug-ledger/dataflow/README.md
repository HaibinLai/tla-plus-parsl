# Core dataflow and Future lifecycle

This file contains the complete ledger entries assigned to this component. See the [split index](../index.md) or the [flat compatibility ledger](../../bug-ledger.md).

| ID | Component | Current behavior / risk | Evidence | Candidate safety condition | Status |
| --- | --- | --- | --- | --- | --- |
| BUG-088 | Failure fan-out mutates task dictionary during iteration | `BlockProviderExecutor.set_bad_state_and_fail_all` iterates `self._tasks` while `Future.set_exception` synchronously runs callbacks. A callback that removes its task entry raises `RuntimeError: dictionary changed size during iteration`, so executor failure handling can stop before all tasks are failed. | `ParslBadStateTaskMutationCurrent.cfg` (2-state `MutationSafety` counterexample); fixed 6 generated/3 distinct; `tests/test_bad_state_task_mutation_runtime.py::test_callback_removing_task_breaks_current_failure_fanout` | Snapshot task entries before completing Futures, or otherwise make failure fan-out mutation-safe. | Reproduced against the installed Parsl source; candidate fixed model passes |

