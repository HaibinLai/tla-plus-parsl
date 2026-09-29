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

`ParslMonitoringDispatchEnvelope.tla` models the outer queue tuple consumed by
`DatabaseManager._dispatch_to_internal`. The current assertion lets a tuple with the wrong
length escape and terminate the migration thread; the fixed branch rejects it while preserving
the manager loop. The runtime probe calls the concrete dispatch method with a malformed tuple.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDispatchEnvelopeCurrent.cfg models/monitoring/ParslMonitoringDispatchEnvelope.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDispatchEnvelopeFixed.cfg models/monitoring/ParslMonitoringDispatchEnvelope.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDispatchEnvelopeValid.cfg models/monitoring/ParslMonitoringDispatchEnvelope.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_dispatch_envelope_runtime.py -v
```

Files live in [`models/monitoring/`](../models/monitoring/).

`ParslMonitoringMalformedWorkerMessage.tla` models worker-task monitoring input whose `first_msg`
and `last_msg` flags are both false. The current database-manager loop raises `RuntimeError` and
terminates its processing thread; the fixed branch discards the malformed message and keeps the
worker alive. The runtime probe drives the real manager in a short-lived thread and captures the
uncaught exception.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringMalformedWorkerMessageCurrent.cfg models/monitoring/ParslMonitoringMalformedWorkerMessage.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringMalformedWorkerMessageFixed.cfg models/monitoring/ParslMonitoringMalformedWorkerMessage.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_malformed_worker_message_runtime.py -v
```

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

`ParslMonitoringDBPermanentError.tla` models a non-retryable database failure in
`DatabaseManager._insert`. The current implementation rolls back and swallows the exception
after the batch has been drained from its queue, so the monitoring message is lost. The fixed
branch retains the message for a later retry. The runtime probe injects a real `DatabaseManager`
instance with a fake database that raises a permanent error.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBPermanentErrorCurrent.cfg models/monitoring/ParslMonitoringDBPermanentError.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBPermanentErrorFixed.cfg models/monitoring/ParslMonitoringDBPermanentError.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_db_permanent_error_runtime.py -v
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
