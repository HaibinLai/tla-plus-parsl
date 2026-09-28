# Monitoring models

`ParslMonitoringTaskRetry.tla` binds retry ordering to a logical task. It models DFK state
transitions, per-attempt status events, queue reordering, and the database current view. The
current configuration finds a `DatabaseVersionSafety` counterexample when an older retry event
is written after a newer event; the fixed configuration preserves the high-water mark and passes
1,084 generated states (353 distinct states).

The action mapping follows `DataFlowKernel._update_task_state` in `dataflow/dflow.py`, and the
`Status` table plus `_insert` retry/rollback path in `monitoring/db_manager.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringTaskRetry.cfg models/monitoring/ParslMonitoringTaskRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringTaskRetryFixed.cfg models/monitoring/ParslMonitoringTaskRetry.tla
```

These models cover asynchronous monitoring records, database insertion, batching, retry and
atomicity, deferred events, close behavior, and batching-threshold edge cases.

Files live in [`models/monitoring/`](../models/monitoring/).

`ParslMonitoringDelivery.tla` is the compact end-to-end event path. It models logical status
versions, an asynchronous queue, reordering, and database writes. The current configuration finds
a `DatabaseMonotonic` counterexample when an older event overwrites a newer record. The fixed
configuration ignores that stale event and checks 1,978 states with all four invariants passing.
