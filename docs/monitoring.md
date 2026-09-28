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

`ParslMonitoringShutdownRace.tla` isolates the complementary late-producer race: if
`Queue.empty()` is observed after the kill event but a producer enqueues immediately afterward,
the current migration loop can exit with a stranded message. The fixed branch requires producer
closure before treating an empty queue as terminal. The runtime probe uses a deterministic fake
queue to reproduce the ordering.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringShutdownRaceCurrent.cfg models/monitoring/ParslMonitoringShutdownRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringShutdownRaceFixed.cfg models/monitoring/ParslMonitoringShutdownRace.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_shutdown_race_runtime.py -v
```

`ParslMonitoringPersistentRetry.tla` models the persistent database-lock boundary. The current
`DatabaseManager._insert` retries every `OperationalError` forever, so a lock that never clears
can prevent the monitoring thread from completing shutdown. The fixed branch bounds retries and
records an aborted write. The runtime probe uses a controllable always-locked fake database and a
watchdog to confirm that the current loop does not return until externally interrupted.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringPersistentRetryCurrent.cfg models/monitoring/ParslMonitoringPersistentRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringPersistentRetryFixed.cfg models/monitoring/ParslMonitoringPersistentRetry.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_persistent_retry_runtime.py -v
```

`ParslFilesystemRadioAtomicity.tla` models the filesystem monitoring radio's publication
protocol. The current direct-write branch lets a reader observe a partial message; the fixed
branch writes under `tmp/` and atomically renames into `new/`. TLC finds the expected current
counterexample and checks 13 generated/6 distinct states for the fixed branch. The runtime probe
uses the real `FilesystemRadioSender` to verify complete pickle visibility and failure isolation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslFilesystemRadioAtomicityCurrent.cfg models/monitoring/ParslFilesystemRadioAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslFilesystemRadioAtomicityFixed.cfg models/monitoring/ParslFilesystemRadioAtomicity.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_filesystem_radio_runtime.py -v
```
