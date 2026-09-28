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

`ParslMonitoringLastMessageRace.tla` covers the complementary ordering race in
`DatabaseManager._db_mgmt_loop`: first worker messages are deferred until their `TRY` row exists,
but last worker messages are currently inserted into `STATUS` immediately. The current
configuration reaches a status row before its try row; the fixed configuration defers and replays
the last message as well. The runtime probe uses a real SQLite-backed `DatabaseManager` and
reproduces the current ordering.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringLastMessageRaceCurrent.cfg models/monitoring/ParslMonitoringLastMessageRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringLastMessageRaceFixed.cfg models/monitoring/ParslMonitoringLastMessageRace.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_last_message_runtime.py -v
```

`ParslMonitoringShutdownDrain.tla` models the normal close boundary: setting the kill event does
not discard messages already accepted by the external resource queue. The migration thread and
database loop continue until their queues are empty. TLC checks message conservation, and
`tests/test_monitoring_shutdown_drain_runtime.py` drives the real migration thread.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringShutdownDrain.cfg models/monitoring/ParslMonitoringShutdownDrain.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_shutdown_drain_runtime.py -v
```
