# Monitoring models

`ParslDfkExecutorShutdownMonitoring.tla` composes the concrete
`DataFlowKernel.cleanup()` executor-shutdown loop with final workflow monitoring. The Current
branch aborts cleanup when one executor's `shutdown()` raises, before sending `WORKFLOW_INFO` or
closing the monitoring hub. The Fixed branch isolates the executor error and still publishes a
terminal workflow outcome before closing monitoring. The runtime bridge uses the installed DFK
cleanup method with a failing executor double; this boundary is recorded as BUG-321.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/monitoring/ParslDfkExecutorShutdownMonitoringCurrent.cfg models/monitoring/ParslDfkExecutorShutdownMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/monitoring/ParslDfkExecutorShutdownMonitoringFixed.cfg models/monitoring/ParslDfkExecutorShutdownMonitoring.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_dfk_executor_shutdown_monitoring_runtime.py -v
```

`ParslMonitoringTaskTryWorkerLifecycle.tla` composes the deferred worker-first path with the
TASK/TRY inserts and the paired STATUS/TRY running update. The Current branch permits one table
to advance when the other write fails; the Fixed branch retains the worker event and avoids a
partial cross-table observation. The runtime bridge is
`tests/test_monitoring_task_try_worker_lifecycle_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/monitoring/ParslMonitoringTaskTryWorkerLifecycleCurrent.cfg models/monitoring/ParslMonitoringTaskTryWorkerLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -config models/monitoring/ParslMonitoringTaskTryWorkerLifecycleFixed.cfg models/monitoring/ParslMonitoringTaskTryWorkerLifecycle.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_task_try_worker_lifecycle_runtime.py -v
```

`ParslMonitoringRemoteLifecycle.tla` composes the remote resource monitor's periodic
intermediate samples with its unconditional final resource message.  The model keeps wall
clock and monotonic time separate: a rollback may suppress a wall-clock intermediate sample in
the Current path, but termination still produces exactly one final message.  The Fixed path
uses monotonic elapsed time for scheduling.  The runtime bridge is
`tests/test_monitoring_remote_lifecycle_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringRemoteLifecycleCurrent.cfg models/monitoring/ParslMonitoringRemoteLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringRemoteLifecycleFixed.cfg models/monitoring/ParslMonitoringRemoteLifecycle.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_remote_lifecycle_runtime.py -v
```

`ParslMonitoringWrapperCleanup.tla` audits the application wrapper's final monitoring send.  If
the wrapped function fails and `send_last_message` fails in the `finally` path, the Current branch
observes the monitoring exception instead of the application exception (BUG-334).  The Fixed
branch treats final-send failure as secondary cleanup and preserves the primary application
failure.  The runtime bridge uses the installed `monitor_wrapper` with deterministic send
doubles.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringWrapperCleanupCurrent.cfg models/monitoring/ParslMonitoringWrapperCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringWrapperCleanupFixed.cfg models/monitoring/ParslMonitoringWrapperCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_wrapper_cleanup_runtime.py -v
```

`ParslMonitoringFailureShutdown.tla` composes permanent WORKFLOW-end update failure with the
database-manager close path. The Current branch marks finalization and stops after losing the
failed update; the Fixed branch bounds retries and records either a persisted or explicit dropped
terminal outcome before stopping.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringFailureShutdownCurrent.cfg models/monitoring/ParslMonitoringFailureShutdown.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringFailureShutdownFixed.cfg models/monitoring/ParslMonitoringFailureShutdown.tla
```

`ParslMonitoringZMQTupleShape.tla` models the router admission boundary before messages enter the
database queue: exactly two-element tuples are forwarded, while malformed tuple lengths are
discarded and the listener continues. `tests/test_monitoring_zmq_tuple_shape_runtime.py` drives
the real `MonitoringRouter.start` loop with one malformed and one valid message.

`ParslMonitoringTaskRetry.tla` binds retry ordering to a logical task. It models DFK state
transitions, per-attempt status events, queue reordering, and the database current view. The
current configuration finds a `DatabaseVersionSafety` counterexample when an older retry event
is written after a newer event; the fixed configuration preserves the high-water mark and passes
1,084 generated states (353 distinct states).

The action mapping follows `DataFlowKernel._update_task_state` in `dataflow/dflow.py`, and the
`Status` table plus `_insert` retry/rollback path in `monitoring/db_manager.py`.

The Fixed configuration is now part of the foundational smoke gate, so retry-event reordering is
checked together with the other monitoring database boundaries.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringTaskRetry.cfg models/monitoring/ParslMonitoringTaskRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringTaskRetryFixed.cfg models/monitoring/ParslMonitoringTaskRetry.tla
```

`ParslMonitoringTimeoutLateEvent.tla` composes a logical timeout with asynchronous database
delivery. A late success event can arrive while the timeout event is queued or being retried
after a transient database failure. The Current branch writes that stale success and violates
`TimeoutDatabaseSafety`; the Fixed branch rejects it, keeps the database aligned with the
timed-out Future, and preserves the bounded retry count.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringTimeoutLateEventCurrent.cfg models/monitoring/ParslMonitoringTimeoutLateEvent.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringTimeoutLateEventFixed.cfg models/monitoring/ParslMonitoringTimeoutLateEvent.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_persistent_retry_runtime.py tests/test_monitoring_update_persistent_retry_runtime.py -v
```

`ParslResultMonitoringAttempt.tla` composes that retry ordering with terminal result persistence.
After attempt 0 is replaced by attempt 1, the Fixed branch turns an old result into a stale event
instead of resolving the Future or writing `succeeded` for the old attempt. The runtime bridge
uses the real SQLite `STATUS` table and verifies that the current `try_id` remains the selected
record.

The same runtime bridge also inserts a newer terminal row followed by a late older-attempt row.
The append-only SQLite history retains both rows, while the current-selection high-water remains
on the newer `try_id`; this is the concrete counterpart of `ParslMonitoringVersionedBatch`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslResultMonitoringAttemptCurrent.cfg models/monitoring/ParslResultMonitoringAttempt.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslResultMonitoringAttemptFixed.cfg models/monitoring/ParslResultMonitoringAttempt.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_result_monitoring_attempt_runtime.py -v
```

`ParslMonitoringResultShutdown.tla` adds the database-manager shutdown boundary to that result
protocol. A queued result can race with `_kill_event`; the Current branch can stop while work is
still queued, or persist an old-attempt result as terminal success. The Fixed branch drains the
queue before stopping and ignores results whose attempt is no longer current. This maps to the
`DatabaseManager.start` queue loop, `_insert` status path, and the logical Future/attempt state.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=50000 -seed 1 \
  -config models/monitoring/ParslMonitoringResultShutdownCurrent.cfg \
  models/monitoring/ParslMonitoringResultShutdown.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=50000 -seed 1 \
  -config models/monitoring/ParslMonitoringResultShutdownFixed.cfg \
  models/monitoring/ParslMonitoringResultShutdown.tla
```

`ParslMonitoringEventStream.tla` is the compact producer-to-database stream model. It has
per-task logical status versions, a bounded event queue, duplicate and reordered events, a
single database writer with bounded write retry, and an explicit producer/database shutdown
drain. The current configuration demonstrates that an older event can roll back a task's
database view; the fixed configuration compares event versions against the per-task high-water
mark and passes 100,001 simulated states. This corresponds to
`DatabaseManager`'s external radio queues, internal pending queues, `_db_mgmt_loop`, and
`_insert` path in `parsl/monitoring/db_manager.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=1000 \
  -config models/monitoring/ParslMonitoringEventStreamCurrent.cfg \
  models/monitoring/ParslMonitoringEventStream.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=1000 \
  -config models/monitoring/ParslMonitoringEventStreamFixed.cfg \
  models/monitoring/ParslMonitoringEventStream.tla
```

This retry/high-water model is included in `scripts/tlc_recent_models.sh`. Together with
`test_monitoring_status_history_runtime.py`, it connects asynchronous retry events to the real
SQLite status-history ordering: an older attempt must not replace a newer terminal record.

These models cover asynchronous monitoring records, database insertion, batching, retry and
atomicity, deferred events, close behavior, and batching-threshold edge cases.

`ParslMonitoringWorkerTryAtomicity.tla` complements the worker first-message model. The current
`DatabaseManager._db_mgmt_loop` commits a `STATUS` insert before updating the corresponding
`TRY` row; if the second write fails, the two tables disagree. The fixed branch retains the event
or rolls back the first write until both tables can be made consistent. The runtime probe drives
the real loop with a successful STATUS write followed by a deterministic TRY update failure.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringWorkerTryAtomicityCurrent.cfg models/monitoring/ParslMonitoringWorkerTryAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringWorkerTryAtomicityFixed.cfg models/monitoring/ParslMonitoringWorkerTryAtomicity.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_worker_try_atomicity_runtime.py -v
```

This cross-table failure boundary is recorded as BUG-265.

`ParslMonitoringInternalQueueDrain.tla` models shutdown of the database manager while an
internal pending queue still contains a message. The current `DatabaseManager.start` loop uses
`queue.empty()` in its stop condition; a stale true observation after `_kill_event` is set can
exit the loop without draining that message. The fixed branch drains pending work before exit.
`tests/test_monitoring_internal_queue_drain_runtime.py` invokes the real `DatabaseManager.start`
with deterministic stale-empty internal queues. This boundary is recorded as BUG-270.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringInternalQueueDrainCurrent.cfg models/monitoring/ParslMonitoringInternalQueueDrain.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringInternalQueueDrainFixed.cfg models/monitoring/ParslMonitoringInternalQueueDrain.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_internal_queue_drain_runtime.py -v
```

`ParslMonitoringQueueFairness.tla` isolates the queue-service policy in
`DatabaseManager._db_mgmt_loop`: priority, worker-task, and resource queues are
visited in sequence, and `_get_messages_in_batch` caps each visit at
`batching_threshold`. The Current branch models an implementation that lets a
continuously replenished priority queue monopolize the loop; the Fixed branch
admits a lower-priority message during the bounded visit. The runtime probe
checks the source helper's threshold behavior directly. This is a bounded
fairness abstraction, not a claim that the current Parsl implementation has
the modeled starvation bug.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringQueueFairnessCurrent.cfg models/monitoring/ParslMonitoringQueueFairness.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringQueueFairnessFixed.cfg models/monitoring/ParslMonitoringQueueFairness.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_queue_fairness_runtime.py -v
```

`ParslMonitoringStatusHistory.tla` is the append-only status-history abstraction.  It permits
event delivery to be reordered but keeps every `(task, run, status, timestamp)` event as a row;
the latest status is derived from the greatest event version rather than insertion order.  The
TLC model checks 150 generated/53 distinct states.  The runtime bridge inserts the same three
events into the real SQLite-backed `Database` in a deliberately non-chronological order and
verifies the ordered history and terminal row.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringStatusHistory.cfg models/monitoring/ParslMonitoringStatusHistory.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_status_history_runtime.py -v
```

`ParslMonitoringDBInsert.tla` isolates duplicate `STATUS` primary-key handling. The current
configuration rolls back and drops a duplicate event; the fixed branch treats it as an idempotent
already-stored row. The normal configuration confirms that a non-duplicate insert remains stored.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBInsert.cfg models/monitoring/ParslMonitoringDBInsert.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBInsertFixed.cfg models/monitoring/ParslMonitoringDBInsert.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBInsertPresent.cfg models/monitoring/ParslMonitoringDBInsert.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_db_runtime.py -v
```

`ParslMonitoringDBSmoke.cfg` is the fast complete check for the compact asynchronous database
model: two logical versions, a one-message radio queue, and one bounded write failure. It checks
757 generated and 291 distinct states and is equivalent to the default small configuration.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBSmoke.cfg models/monitoring/ParslMonitoringDB.tla
```

`ParslMonitoringResourceHistory.tla` covers the append-only `RESOURCE` table path. Resource
samples may arrive out of timestamp order through the external queue, but each timestamp remains
a distinct database row and a duplicate sample cannot create a second row. The latest observation
is selected by timestamp rather than insertion order. The runtime bridge inserts three samples
into the real SQLite-backed `Database`, attempts a duplicate primary key, and checks the retained
latest value.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringResourceHistory.cfg models/monitoring/ParslMonitoringResourceHistory.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_resource_history_runtime.py -v
```

`ParslMonitoringTaskInsertBookkeeping.tla` models a separate TASK-table failure boundary. The
current `DatabaseManager.start` loop records a task ID in `inserted_tasks` before the SQL insert
has succeeded. If the insert fails, the next message is routed to UPDATE even though the row is
absent. The fixed branch commits the bookkeeping bit only after insertion and retries the insert
path. This is recorded as BUG-129. The runtime probe runs the real start loop with a database
double that rejects TASK inserts and observes one insert followed by an incorrect update.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringTaskInsertBookkeepingCurrent.cfg models/monitoring/ParslMonitoringTaskInsertBookkeeping.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringTaskInsertBookkeepingFixed.cfg models/monitoring/ParslMonitoringTaskInsertBookkeeping.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_task_insert_bookkeeping_runtime.py -v
```

`ParslMonitoringTryInsertBookkeeping.tla` applies the same transaction boundary to the TRY table.
The current loop records a `(task_id, try_id)` in `inserted_tries` before the insert returns, so
a failed first insert causes the next `TASK_INFO` for that attempt to use UPDATE even though no
TRY row exists. The fixed branch records the key only after successful insertion. The runtime
probe drives the real `DatabaseManager.start` loop with a failing TRY insert. This is recorded as
BUG-140.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringTryInsertBookkeepingCurrent.cfg models/monitoring/ParslMonitoringTryInsertBookkeeping.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringTryInsertBookkeepingFixed.cfg models/monitoring/ParslMonitoringTryInsertBookkeeping.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_try_insert_bookkeeping_runtime.py -v
```

`ParslMonitoringWorkflowInsertBookkeeping.tla` applies the same success-before-bookkeeping rule
to the workflow start row. The current path records `workflow_start_message` even when the
WORKFLOW insert fails, so abnormal close later attempts an UPDATE against a missing row. The
fixed branch records the marker only after insertion succeeds. The runtime probe drives the real
`DatabaseManager.start` and `close` methods with a failing WORKFLOW insert. This is recorded as
BUG-141.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringWorkflowInsertBookkeepingCurrent.cfg models/monitoring/ParslMonitoringWorkflowInsertBookkeeping.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringWorkflowInsertBookkeepingFixed.cfg models/monitoring/ParslMonitoringWorkflowInsertBookkeeping.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_workflow_insert_bookkeeping_runtime.py -v
```

`ParslMonitoringWorkflowEndBookkeeping.tla` covers the close-side counterpart. The current loop
sets `workflow_end` after a failed WORKFLOW update, so later `close()` calls skip the missing
update; the fixed branch keeps the end marker false until persistence succeeds. The runtime
probe observes a failed update and confirms that close performs no retry. This is recorded as
BUG-142.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringWorkflowEndBookkeepingCurrent.cfg models/monitoring/ParslMonitoringWorkflowEndBookkeeping.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringWorkflowEndBookkeepingFixed.cfg models/monitoring/ParslMonitoringWorkflowEndBookkeeping.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_workflow_end_bookkeeping_runtime.py -v
```

`ParslMonitoringLifecycleBookkeeping.tla` composes the TASK, TRY, and WORKFLOW insert markers with
workflow finalization in one small state machine. It checks that each in-memory bookkeeping flag
advances only after its database row exists, including the close-side end update. The Current
configuration intentionally permits all four flags to advance after failed writes; the Fixed
configuration preserves recovery invariants across the complete monitoring lifecycle. The focused
runtime probes for TASK/TRY/WORKFLOW insert and end bookkeeping exercise the corresponding real
`DatabaseManager.start` and `close` paths.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringLifecycleBookkeepingCurrent.cfg models/monitoring/ParslMonitoringLifecycleBookkeeping.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringLifecycleBookkeepingFixed.cfg models/monitoring/ParslMonitoringLifecycleBookkeeping.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_task_insert_bookkeeping_runtime.py tests/test_monitoring_try_insert_bookkeeping_runtime.py tests/test_monitoring_workflow_insert_bookkeeping_runtime.py tests/test_monitoring_workflow_end_bookkeeping_runtime.py -v
```

`ParslMonitoringHubClose.tla` models the outer `MonitoringHub.close()` lifecycle. Closing signals
the DB process, waits for it, closes the resource queue, and joins the queue thread. The active
flag makes repeated close calls idempotent. The runtime probe uses the real method with counting
process/event/queue doubles.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringHubClose.cfg models/monitoring/ParslMonitoringHubClose.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_hub_close_runtime.py -v
```

`ParslMonitoringHubCloseBeforeStart.tla` covers cleanup before the monitoring hub has been
started. The current constructor leaves `monitoring_hub_active` undefined, so `close()` raises
before it can be idempotent; the fixed branch treats an unstarted hub as already closed. The
runtime probe invokes the real `MonitoringHub.close()` on an unstarted instance.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringHubCloseBeforeStartCurrent.cfg models/monitoring/ParslMonitoringHubCloseBeforeStart.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringHubCloseBeforeStartFixed.cfg models/monitoring/ParslMonitoringHubCloseBeforeStart.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_hub_close_before_start_runtime.py -v
```

`ParslMonitoringHubStartFailureCleanup.tla` covers failure after `MonitoringHub.start()` has
allocated its queue and process wrapper but before the child process starts. The current path
propagates the startup exception while leaving the hub active; the fixed path rolls back the
active/resource state before propagation. The runtime probe uses deterministic queue, event, and
process doubles.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringHubStartFailureCleanupCurrent.cfg models/monitoring/ParslMonitoringHubStartFailureCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringHubStartFailureCleanupFixed.cfg models/monitoring/ParslMonitoringHubStartFailureCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_hub_start_failure_cleanup_runtime.py -v
```

`ParslMonitoringHubRepeatedStart.tla` covers the active-state guard around a second
`MonitoringHub.start()` call. The current implementation allocates a second DB process and queue
and overwrites the first handles; the fixed branch leaves the original owner intact. The runtime
probe starts the real method twice with deterministic process/queue doubles.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringHubRepeatedStartCurrent.cfg models/monitoring/ParslMonitoringHubRepeatedStart.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringHubRepeatedStartFixed.cfg models/monitoring/ParslMonitoringHubRepeatedStart.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_hub_repeated_start_runtime.py -v
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

This persistent-failure boundary is recorded as BUG-124: the router retries a broken receive
channel until external shutdown without a bounded/backoff policy.

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

`ParslMonitoringZMQBatchClock.tla` applies the same deadline abstraction to the ZMQ monitoring
router. `MonitoringRouter.start` measures each one-second receive batch with `time.time()`;
rollback can therefore keep the inner receive loop active after its intended deadline. The
current model reproduces the overrun, while the fixed branch advances a monotonic deadline.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringZMQBatchClockCurrent.cfg models/monitoring/ParslMonitoringZMQBatchClock.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringZMQBatchClockFixed.cfg models/monitoring/ParslMonitoringZMQBatchClock.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_zmq_batch_clock_runtime.py -v
```

This ZMQ batch-deadline boundary is recorded as BUG-247.

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

This malformed-input boundary is recorded as BUG-106 because the current exception escapes the
monitoring worker thread.

`ParslMonitoringDelivery.tla` is the compact end-to-end event path. It models logical status
versions, an asynchronous queue, reordering, and database writes. The current configuration finds
a `DatabaseMonotonic` counterexample when an older event overwrites a newer record. The fixed
configuration ignores that stale event and checks 1,978 states with all four invariants passing.
The fixed configuration is now part of the foundational smoke gate, while the Current
configuration remains an executable stale-write counterexample.

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

`ParslMonitoringDeferredMultiplicity.tla` refines the first-message deferral boundary to three
observations for the same task/try before the `TRY` row exists. The current one-entry dictionary
overwrites earlier observations; the candidate fixed path retains the bounded sequence until
replay. TLC finds the current `NoDeferredLoss` counterexample (5 generated/4 distinct states)
and checks 28 generated/14 distinct fixed states. The runtime probe uses the real SQLite-backed
manager and checks that only the later hostname survives today.

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

`ParslMonitoringDBRetryFuture.tla` composes the persistent-lock boundary with task/Future
terminality. A task may already be successful while its status write is retried; the Current
branch can remain in retrying forever at the attempt bound, while the Fixed branch records an
aborted monitoring write without rolling back the Future. Stored monitoring is required to
correspond to a successful Future. The existing persistent-retry runtime probes exercise the
real DatabaseManager loop. `tests/test_monitoring_db_retry_future_runtime.py` additionally calls
the real `_insert` method with a one-shot `OperationalError` and verifies that the already
terminal application Future is unchanged while the database write retries.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBRetryFutureCurrent.cfg models/monitoring/ParslMonitoringDBRetryFuture.tla
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

`ParslMonitoringUDPDrainClock.tla` models the UDP router's shutdown drain
deadline. The current `MonitoringRouter.start` uses `time.time()` for the
last-message baseline, so a wall-clock rollback can keep the drain loop alive
after `atexit_timeout`; the fixed branch uses monotonic elapsed time. The
runtime probe drives the real router loop with a timeout-only socket double and
a decreasing wall-clock sequence.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslMonitoringUDPDrainClockCurrent.cfg models/clock/ParslMonitoringUDPDrainClock.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslMonitoringUDPDrainClockFixed.cfg models/clock/ParslMonitoringUDPDrainClock.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_udp_drain_clock_runtime.py -v
```

This UDP drain-deadline boundary is recorded as BUG-240.

`ParslMonitoringStarterConstructionFailure.tla` models failure before the monitoring database
manager is constructed. The current `dbm_starter` exception handler unconditionally calls
`dbm.close()`, so a constructor exception is replaced by `UnboundLocalError`; the fixed branch
preserves the original construction failure. The runtime probe patches the real starter's
`DatabaseManager` constructor.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringStarterConstructionFailureCurrent.cfg models/monitoring/ParslMonitoringStarterConstructionFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringStarterConstructionFailureFixed.cfg models/monitoring/ParslMonitoringStarterConstructionFailure.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_starter_construction_failure_runtime.py -v
```

`ParslResourceMonitorClock.tla` covers the worker-side resource monitor in
`parsl.monitoring.remote`. The current loop uses `time.time()` for periodic sampling; a backward
wall-clock step can suppress an already-due intermediate resource message. The fixed branch uses
elapsed monotonic time for scheduling while leaving wall-clock timestamps in monitoring records.
The source-level fake-process probe is
[`tests/test_resource_monitor_clock_runtime.py`](../tests/test_resource_monitor_clock_runtime.py).

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslResourceMonitorClockCurrent.cfg models/clock/ParslResourceMonitorClock.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslResourceMonitorClockFixed.cfg models/clock/ParslResourceMonitorClock.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_resource_monitor_clock_runtime.py -v
```

### Monitoring queue fairness audit

The database manager drains the priority queue first, but `_get_messages_in_batch` bounds each
batch by both `batching_interval` and `batching_threshold`; the loop then services node, block,
worker-task, and resource queues in the same iteration. Unlike the HTEX worker poll path, this
ordering does not by itself create an unbounded priority-queue starvation model. The existing
shutdown and stale-`empty()` models remain the relevant monitoring queue-loss boundaries.
`ParslFutureProjectionRetryMonitoring.tla` composes logical Future retry with the monitoring
status high-water mark. The projection is admitted only after the current physical attempt is
published as done; a late status from the failed attempt is isolated as stale and cannot move the
database back to an older attempt.
