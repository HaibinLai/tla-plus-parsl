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

`ParslMonitoringDBInsert.tla` isolates duplicate `STATUS` primary-key handling. The current
configuration rolls back and drops a duplicate event; the fixed branch treats it as an idempotent
already-stored row. The normal configuration confirms that a non-duplicate insert remains stored.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBInsert.cfg models/monitoring/ParslMonitoringDBInsert.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBInsertFixed.cfg models/monitoring/ParslMonitoringDBInsert.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBInsertPresent.cfg models/monitoring/ParslMonitoringDBInsert.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_db_runtime.py -v
```

`ParslMonitoringHubClose.tla` models the outer `MonitoringHub.close()` lifecycle. Closing signals
the DB process, waits for it, closes the resource queue, and joins the queue thread. The active
flag makes repeated close calls idempotent. The runtime probe uses the real method with counting
process/event/queue doubles.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringHubClose.cfg models/monitoring/ParslMonitoringHubClose.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_hub_close_runtime.py -v
```

`ParslMonitoringCloseIdempotence.tla` models repeated abnormal
`DatabaseManager.close()` calls. The current implementation leaves
`workflow_end` false after finalization, so each close emits another workflow
update; the fixed branch records the finalization and makes later closes
no-ops. The runtime probe calls the real method twice with a controlled update
callback.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringCloseIdempotenceCurrent.cfg models/monitoring/ParslMonitoringCloseIdempotence.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringCloseIdempotenceFixed.cfg models/monitoring/ParslMonitoringCloseIdempotence.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_close_idempotence_runtime.py -v
```

`ParslMonitoringZMQRouterFailure.tla` models a permanently broken receive channel in the
monitoring ZMQ router. The current loop catches the receive exception and retries indefinitely
until an external exit event arrives; the fixed branch stops after the first unrecoverable
failure. The runtime probe drives the real `MonitoringRouter.start` loop with a receiver that
always raises.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringZMQRouterFailureCurrent.cfg models/monitoring/ParslMonitoringZMQRouterFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringZMQRouterFailureFixed.cfg models/monitoring/ParslMonitoringZMQRouterFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringZMQRouterFailureValid.cfg models/monitoring/ParslMonitoringZMQRouterFailure.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_zmq_router_failure_runtime.py -v
```

`ParslMonitoringBatchClock.tla` isolates the clock source used by
`DatabaseManager._get_messages_in_batch`. With the current `time.time()` path, a wall-clock
rollback makes elapsed time negative and allows a batch to consume messages beyond its one-second
deadline. The fixed branch uses monotonic time and stops at the deadline. The runtime probe uses
a deterministic clock sequence against the real batching helper.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchClockCurrent.cfg models/monitoring/ParslMonitoringBatchClock.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchClockFixed.cfg models/monitoring/ParslMonitoringBatchClock.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_batch_clock_runtime.py -v
```

This batching-clock boundary is recorded as BUG-090: the current implementation is sensitive to
wall-clock rollback, while the candidate fixed model uses a monotonic deadline.

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

`ParslFileTransferMonitoring.tla` connects that database path to output-file publication. A
terminal event carries the stage-out's captured file version. The current configuration can write
success before stage-out or with an obsolete version; TLC finds a `MonitoringFileSafety`
counterexample at depth 4 (33 states generated). The fixed configuration requires version-matched
DataFuture readiness before emitting or persisting success and checks 42 distinct states.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslFileTransferMonitoringCurrent.cfg models/monitoring/ParslFileTransferMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslFileTransferMonitoringFixed.cfg models/monitoring/ParslFileTransferMonitoring.tla
```

`StartStageOut`, `PublishStageOut`, and `EmitSuccess` correspond to DFK/DataManager output
completion and monitoring status emission; `PersistSuccess` abstracts the SQLite status write.
The related concrete probes are the DataFuture/stage-out tests and monitoring database delivery
tests under `tests/`.

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

`ParslMonitoringDeferredMultiplicity.tla` refines the first-message deferral boundary to two
observations for the same task/try before the `TRY` row exists. The current one-entry dictionary
overwrites the earlier observation; the candidate fixed path retains both until replay. TLC finds
the current `NoDeferredLoss` counterexample (5 generated/4 distinct states) and checks 18
generated/9 distinct fixed states. The runtime probe uses the real SQLite-backed manager and
checks that only the later hostname survives today.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDeferredMultiplicityCurrent.cfg models/monitoring/ParslMonitoringDeferredMultiplicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDeferredMultiplicityFixed.cfg models/monitoring/ParslMonitoringDeferredMultiplicity.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_deferred_multiplicity_runtime.py -v
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

`ParslMonitoringUpdatePersistentRetry.tla` applies the bounded-retry abstraction to the separate
`_update` path. The source has an independent `OperationalError` loop, so a permanent lock can
strand update processing even when insert handling is considered separately. The runtime probe
uses a real `DatabaseManager._update` call with an always-locked fake database and a controlled
stop signal.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringUpdatePersistentRetryCurrent.cfg models/monitoring/ParslMonitoringUpdatePersistentRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringUpdatePersistentRetryFixed.cfg models/monitoring/ParslMonitoringUpdatePersistentRetry.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_update_persistent_retry_runtime.py -v
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

`ParslMonitoringDBUpdatePermanentError.tla` applies the same retention property to
`DatabaseManager._update`. A permanent non-locking database error is rolled back and swallowed by
the current implementation after the update batch has been drained; the fixed branch retains the
message for a later retry. The runtime probe invokes the concrete update path with a failing
database double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBUpdatePermanentErrorCurrent.cfg models/monitoring/ParslMonitoringDBUpdatePermanentError.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBUpdatePermanentErrorFixed.cfg models/monitoring/ParslMonitoringDBUpdatePermanentError.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_db_update_permanent_error_runtime.py -v
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
