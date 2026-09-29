# Executor and HTEX models

These models cover executor lifecycle, task execution, HTEX submission and result queues, worker
registration, heartbeats, command deadlines, ThreadExecutor, WorkQueue, TaskVine, Flux, and
RadicalPilot result handling.

Files live in [`models/executors/`](../models/executors/). The full TLC command list is in
[the overview](overview.md).

`ParslResultsIncoming.tla` models the concrete `ResultsIncoming` DEALER wrapper in
`high_throughput/zmq_pipes.py`: a readable socket yields one multipart message, a poll timeout
returns `None`, and `close()` shuts down both the socket and its ZMQ context. The two configurations
cover readable and timeout paths, while `tests/test_results_incoming_runtime.py` drives the real
wrapper with a fake socket.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslResultsIncoming.cfg models/executors/ParslResultsIncoming.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslResultsIncomingTimeout.cfg models/executors/ParslResultsIncoming.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_results_incoming_runtime.py -v
```

`ParslTasksOutgoing.tla` covers the matching task sender: `put()` sends one Python object over the
DEALER socket without a reply handshake, and `close()` terminates the socket/context so the sender
is no longer open. `tests/test_tasks_outgoing_runtime.py` checks the real wrapper boundary with a
fake socket.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTasksOutgoing.cfg models/executors/ParslTasksOutgoing.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_tasks_outgoing_runtime.py -v
```

`ParslCommandClientSendTimeout.tla` adds the pre-send timeout branch of the HTEX REQ/REP command
client. A `POLLOUT` timeout occurs before any request is put on the socket, so it leaves
`client.ok` true and a later command can safely retry; this contrasts with a post-send reply
timeout, which poisons the client. The runtime probe checks both the empty first send and the
successful second command.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientSendTimeout.cfg models/executors/ParslCommandClientSendTimeout.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_command_send_timeout_runtime.py -v
```

`ParslCommandClientLockTimeout.tla` models the timeout boundary around the client's Python
mutex. The current `CommandClient.run` starts its deadline before `with self._lock`, so a caller
blocked behind another command can acquire the lock after its deadline and still send. The fixed
branch makes lock acquisition deadline-aware. The runtime probe holds the real lock, invokes
`run(timeout_s=...)` in another thread, and verifies the late send.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientLockTimeoutCurrent.cfg models/executors/ParslCommandClientLockTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientLockTimeoutFixed.cfg models/executors/ParslCommandClientLockTimeout.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_command_lock_timeout_runtime.py -v
```

`ParslCommandClientMaxRetries.tla` records a source-level audit finding: `CommandClient.run`
accepts `max_retries`, but the current implementation does not read it. A transient
`send_pyobj` exception therefore escapes after exactly one send for both `max_retries=0` and
`max_retries=2`. The current TLC configuration violates `RetryBudgetHonored`; the fixed
configuration models one retry and passes. This is an API/implementation mismatch, not an
assumption that the paper requires a particular retry policy.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientMaxRetriesCurrent.cfg models/executors/ParslCommandClientMaxRetries.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientMaxRetriesFixed.cfg models/executors/ParslCommandClientMaxRetries.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_command_max_retries_runtime.py -v
```

`ParslHtexCancelledResult.tla` covers a result arriving after a user cancelled its Future. The
current HTEX result thread calls `set_result` unconditionally; `InvalidStateError` terminates the
thread after removing the cancelled task, so later results in the same batch remain pending. The
fixed branch discards the cancelled result and continues. `tests/test_htex_cancelled_result_runtime.py`
reproduces the current failure with two messages in one batch.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexCancelledResultCurrent.cfg models/executors/ParslHtexCancelledResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexCancelledResultFixed.cfg models/executors/ParslHtexCancelledResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_cancelled_result_runtime.py -v
```

`ParslMPINonDivisibleRanks.tla` audits `MPIExecutor` resource derivation. With `num_nodes=2`
and `num_ranks=5`, the current helper derives `ranks_per_node="2.5"` and emits that value in
the `mpiexec -ppn` option. The current TLC model violates `IntegralRanksSafety`; the fixed branch
rejects the allocation before launch. The runtime probe confirms the exact generated command.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPINonDivisibleRanksCurrent.cfg models/executors/ParslMPINonDivisibleRanks.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPINonDivisibleRanksFixed.cfg models/executors/ParslMPINonDivisibleRanks.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_mpi_nondivisible_runtime.py -v
```

`ParslMPINoResourceResult.tla` models the MPI scheduler result path for a task that did not
request MPI nodes. Such tasks are valid but are not inserted into `_map_tasks_to_nodes`; the
current `get_result` assertion nevertheless requires a mapping and aborts the scheduler. The
fixed branch returns the result without reclaiming nodes. The runtime probe invokes the real
method with an unmapped result payload.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPINoResourceResultCurrent.cfg models/executors/ParslMPINoResourceResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPINoResourceResultFixed.cfg models/executors/ParslMPINoResourceResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_mpi_no_resource_result_runtime.py -v
```

`ParslMPIBacklogRetry.tla` models the MPI backlog scheduler when its head task needs more nodes
than are currently free. The current `_schedule_backlog_tasks` requeues that task and immediately
recurses, so an unchanged resource count eventually raises `RecursionError`. The fixed branch
leaves the task queued until a result returns nodes. The runtime probe drives the real scheduler
with one free node and a two-node request.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPIBacklogRetryCurrent.cfg models/executors/ParslMPIBacklogRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPIBacklogRetryFixed.cfg models/executors/ParslMPIBacklogRetry.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_mpi_backlog_retry_runtime.py -v
```

`ParslBashTimeoutCleanup.tla` covers the Bash app walltime boundary. The current
`remote_side_bash_executor` raises `AppTimeout` after `Popen.wait(timeout=...)` expires but does
not kill the shell/process group, leaving the timed-out command alive. The fixed branch performs
cleanup before reporting the timeout. The runtime probe uses a fake `Popen` to verify that the
current path makes no kill call.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBashTimeoutCleanupCurrent.cfg models/executors/ParslBashTimeoutCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBashTimeoutCleanupFixed.cfg models/executors/ParslBashTimeoutCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_bash_timeout_cleanup_runtime.py -v
```

`ParslHtexForceScaleIn.tla` models the concrete `HighThroughputExecutor.scale_in` policy.
With the default `max_idletime=None`, the current implementation deliberately selects the
longest-idle block even when its manager still reports active tasks, calls `_hold_block`, and
cancels the provider job. The current TLC branch therefore violates `BusyScaleInSafety`; the
fixed branch represents an idle-only policy. The runtime probe uses a busy fake manager and
checks the real block/provider cancellation calls. This captures the source docstring's
explicitly rude forced scale-in behavior (issue #530).

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexForceScaleInCurrent.cfg models/executors/ParslHtexForceScaleIn.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexForceScaleInFixed.cfg models/executors/ParslHtexForceScaleIn.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_force_scale_in_runtime.py -v
```

`ParslWorkQueueCancelledResult.tla` models a Work Queue collector result racing with cancellation.
The current collector removes the cancelled Future and calls `set_result`, so `InvalidStateError`
exits the collector; its `finally` block then marks an unrelated pending Future as
`WorkQueueFailure`. The fixed branch discards the stale result and continues collecting. The
runtime probe drives two fake reports through the real collector method.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueCancelledResultCurrent.cfg models/executors/ParslWorkQueueCancelledResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueCancelledResultFixed.cfg models/executors/ParslWorkQueueCancelledResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_workqueue_cancelled_result_runtime.py -v
```

`ParslTaskVineCancelledResult.tla` covers the corresponding TaskVine collector race. A cancelled
Future causes the current collector's unconditional `set_result` to raise after the report is
removed; cleanup then marks another outstanding Future with `TaskVineManagerFailure`. The fixed
branch ignores the stale report and continues. `tests/test_taskvine_cancelled_result_runtime.py`
drives two real result-file reports through the collector boundary.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineCancelledResultCurrent.cfg models/executors/ParslTaskVineCancelledResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineCancelledResultFixed.cfg models/executors/ParslTaskVineCancelledResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_taskvine_cancelled_result_runtime.py -v
```

`ParslTaskVineFactory.tla` models the optional TaskVine factory process. The factory is created,
configured with worker/factory timeouts and capacity limits, entered as a context manager, and
kept alive until the executor stop event is set. The runtime probe patches the optional TaskVine
SDK with a fake factory and checks the real `_taskvine_factory` configuration boundary.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineFactory.cfg models/executors/ParslTaskVineFactory.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_taskvine_factory_runtime.py -v
```

`ParslTaskVineSubmit.tla` models TaskVine submission ordering. The current executor inserts the
Future into its task map before serializing the callable and before checking submit-process
liveness, so either failure leaves an orphaned Future; the fixed branch rolls that map entry back.
The runtime probe drives both failures through the real `TaskVineExecutor.submit` with fake queues,
process state, and serialization.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineSubmitCurrent.cfg models/executors/ParslTaskVineSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineSubmitFixed.cfg models/executors/ParslTaskVineSubmit.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_taskvine_submit_runtime.py -v
```

`ParslScaleOutFailureMonitoring.tla` models partial provisioning during
`BlockProviderExecutor.scale_out_facade`: one block succeeds and a later provider submission
fails. The current implementation stores the failed block in `_status` and notifies the
monitoring radio, but the BLOCK_INFO payload contains only the successful pending block because
only that branch adds to `monitoring_status_changes`. The fixed branch includes the failed block
in the payload. The runtime probe uses a real `BlockProviderExecutor` subclass and a provider
that succeeds once before raising.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslScaleOutFailureMonitoringCurrent.cfg models/executors/ParslScaleOutFailureMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslScaleOutFailureMonitoringFixed.cfg models/executors/ParslScaleOutFailureMonitoring.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_scale_out_failure_monitoring_runtime.py -v
```

`ParslRadicalPilotFailurePayload.tla` refines the RADICAL-Pilot callback mapping. If a failed
Python task has no serialized exception payload, the current callback passes a string to
`Future.set_exception`, which produces a callback-level `TypeError`; the fixed configuration wraps
the missing payload in a real `RuntimeError`. `test_radical_results_runtime.py` contains the
corresponding source-level probe.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotFailurePayloadCurrent.cfg models/executors/ParslRadicalPilotFailurePayload.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotFailurePayloadFixed.cfg models/executors/ParslRadicalPilotFailurePayload.tla
```

`ParslRadicalPilotLateCallback.tla` models a RADICAL-Pilot `CANCELED` callback racing with a
late `DONE` callback for the same task. The current `task_state_cb` calls `set_result` even
after the Parsl Future has been cancelled, raising `InvalidStateError`; the fixed branch drops
callbacks after terminal state. The runtime probe invokes the real callback twice with a fake RP
task and observes the exception.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotLateCallbackCurrent.cfg models/executors/ParslRadicalPilotLateCallback.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotLateCallbackFixed.cfg models/executors/ParslRadicalPilotLateCallback.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_radical_late_callback_runtime.py -v
```

`ParslRadicalPilotBulkShutdown.tla` models Radical Pilot bulk mode during shutdown. The current
shutdown sets `_terminate` before joining the bulk collector; the collector exits without flushing
its queue, leaving a queued task and its Future unresolved. The fixed branch flushes queued tasks
before exit. The runtime probe invokes the real `_bulk_collector` with a stop event and one queued
task.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotBulkShutdownCurrent.cfg models/executors/ParslRadicalPilotBulkShutdown.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotBulkShutdownFixed.cfg models/executors/ParslRadicalPilotBulkShutdown.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_radical_bulk_shutdown_runtime.py -v
```

`ParslWorkQueueShutdown.tla` models the Work Queue collector's finalization contract. Shutdown
sets the stop flag and waits for the collector; its `finally` block fails every accepted Future
that has no result before the executor reaches `stopped`. The runtime probe invokes the real
collector method with an already-set stop flag and an outstanding Future.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueShutdown.cfg models/executors/ParslWorkQueueShutdown.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_workqueue_shutdown_runtime.py -v
```

`ParslTaskVineShutdown.tla` models the corresponding TaskVine collector path. Its stop event and
task map are separate from Work Queue's, and outstanding Futures receive `TaskVineManagerFailure`
before the collector exits. `tests/test_taskvine_shutdown_runtime.py` invokes the real collector
with a stopped flag and an outstanding Future.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineShutdown.cfg models/executors/ParslTaskVineShutdown.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_taskvine_shutdown_runtime.py -v
```

`ParslFluxSubmissionFailure.tla` covers the Flux submission-thread exception path. `_error_out_jobs`
continues draining queued jobs after the stop event is set and fails each queued Future. The
runtime probe calls that real helper with a one-job queue.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxSubmissionFailure.cfg models/executors/ParslFluxSubmissionFailure.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_flux_submission_failure_runtime.py -v
```

`ParslFluxCancelSubmitRace.tla` models a Flux-specific cancellation race. If the wrapper is
cancelled while `_flux_future` is still unbound, a later successful underlying callback can call
`set_result` on the already-cancelled wrapper. The current configuration reaches the callback
error; the fixed branch propagates the cancellation into the bind step and suppresses the late
callback. `tests/test_flux_cancel_submit_race_runtime.py` reproduces the interleaving directly.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxCancelSubmitRaceCurrent.cfg models/executors/ParslFluxCancelSubmitRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxCancelSubmitRaceFixed.cfg models/executors/ParslFluxCancelSubmitRace.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_flux_cancel_submit_race_runtime.py -v
```

`ParslFluxErrorCleanupCancellation.tla` covers the Flux submit-thread failure cleanup path.
`_error_out_jobs` currently calls `set_exception` on queued Futures without checking whether
the user already canceled them. A canceled first Future can therefore raise `InvalidStateError`
and strand later queued Futures; the fixed branch skips terminal Futures and continues draining.
The runtime probe invokes the real cleanup helper with two queued Futures.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxErrorCleanupCancellationCurrent.cfg models/executors/ParslFluxErrorCleanupCancellation.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxErrorCleanupCancellationFixed.cfg models/executors/ParslFluxErrorCleanupCancellation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_flux_error_cleanup_cancellation_runtime.py -v
```

`ParslGlobusComputeResult.tla` models the result boundary of `GlobusComputeExecutor.submit`.
The wrapper returns the underlying Globus Compute SDK `Future` directly, so success, remote
exception, and cancellation are visible to Parsl without an additional result wrapper. The
runtime probe uses a fake SDK executor and checks Future identity and all three terminal outcomes.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslGlobusComputeResult.cfg models/executors/ParslGlobusComputeResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_compute_result_runtime.py -v
```

`ParslGlobusComputeSubmitRace.tla` refines the other side of that wrapper. The current
`submit` implementation temporarily mutates one shared SDK executor before calling its
`submit`; overlapping calls can therefore make task A observe task B's resource specification
or the restored default. The current TLC branch finds that interleaving, while the fixed branch
serializes the override/submit/restore critical section with a lock. The runtime probe uses two
threads and a deterministic fake SDK executor to reproduce the wrong configuration observation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslGlobusComputeSubmitRaceCurrent.cfg models/executors/ParslGlobusComputeSubmitRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslGlobusComputeSubmitRaceFixed.cfg models/executors/ParslGlobusComputeSubmitRace.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_compute_submit_race_runtime.py -v
```

`ParslExecutorProviderLifecycle.tla` connects provider allocation, manager registration, free
worker slots, queued/running tasks, executor drain, and provider terminal cleanup. The current
configuration finds a `MinBlockSafety` counterexample when scale-in leaves an active provider
below `MIN_BLOCKS`; the fixed configuration enforces the floor and checks 161 states.

`ParslHeartbeatLateAck.tla` isolates the in-flight heartbeat race: a manager can expire before an
old heartbeat reaches the interchange. The current branch accepts that stale acknowledgement and
resurrects the manager, violating `ExpiryTerminal`; the fixed branch ignores it as stale. This
matches the manager-record lookup guard in HTEX `interchange.py` before processing messages.

`ParslHtexSubmitLifecycle.tla` refines HTEX submission ordering. Serialization failure
terminates before a task/Future is allocated, while an outgoing-queue failure happens after
allocation. The current queue-failure configuration leaves an orphaned pending Future and
violates `QueueFailureSafety`; the fixed configuration removes the task mapping and fails the
Future. The serialization-failure configuration passes with no Future allocation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexSubmitLifecycleQueueFailure.cfg models/executors/ParslHtexSubmitLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexSubmitLifecycleQueueFailureFixed.cfg models/executors/ParslHtexSubmitLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexSubmitLifecycleSerializationFailure.cfg models/executors/ParslHtexSubmitLifecycle.tla
```

Run this focused check with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatLateAck.cfg models/executors/ParslHeartbeatLateAck.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatLateAckFixed.cfg models/executors/ParslHeartbeatLateAck.tla
```

`ParslBlockProviderBadState.tla` captures the shared `BlockProviderExecutor` failure path:
an unrecoverable provider error records the exception, fails every outstanding Future with a
`BadStateException`, and rejects later submissions while preserving already terminal tasks.
The runtime probe calls `set_bad_state_and_fail_all` on a small concrete subclass.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadState.cfg models/executors/ParslBlockProviderBadState.tla
```

`ParslBlockProviderBadStateOrdering.tla` refines that path with iteration order. The current
implementation calls `set_exception` on every task Future without checking `done()`: a completed
Future can raise `InvalidStateError` and prevent later pending tasks from being failed. TLC finds
the two-state counterexample; the fixed branch skips terminal Futures. The runtime probe uses a
completed entry followed by a pending entry to reproduce the partial failure sweep.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateOrderingCurrent.cfg models/executors/ParslBlockProviderBadStateOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateOrderingFixed.cfg models/executors/ParslBlockProviderBadStateOrdering.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_block_provider_bad_state_order_runtime.py -v
```

`ParslBlockProviderBadStateMutation.tla` models callback mutation during the same failure sweep.
`Future.set_exception()` runs callbacks synchronously, so a callback that mutates `_tasks` can
make the live dictionary iterator raise `RuntimeError`, leaving another original task pending.
The fixed branch iterates a snapshot. The runtime probe registers exactly this callback mutation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateMutationCurrent.cfg models/executors/ParslBlockProviderBadStateMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateMutationFixed.cfg models/executors/ParslBlockProviderBadStateMutation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_block_provider_bad_state_mutation_runtime.py -v
```

`ParslHtexManagerSelection.tla` abstracts the two manager selectors in
`high_throughput/manager_selector.py`. Random selection is modeled as any permutation of ready
managers; block-ID selection preserves the source ordering rule, including managers with no block
ID and lexicographic block IDs. The runtime probe invokes both concrete selector classes.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerSelection.cfg models/executors/ParslHtexManagerSelection.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerSelectionBlock.cfg models/executors/ParslHtexManagerSelection.tla
```

`ParslJobStatusOutputSummary.tla` models the concrete output-file behavior of
`JobStatus.stdout_summary` and `stderr_summary`: a missing path/file yields no output, files at
or below 2048 bytes are returned in full, and larger files preserve only the head and tail with
an ellipsis marker. `tests/test_job_status_output_summary_runtime.py` checks these boundaries
against real temporary files.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputSummary.cfg models/executors/ParslJobStatusOutputSummary.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputSummaryLarge.cfg models/executors/ParslJobStatusOutputSummary.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputSummaryMissing.cfg models/executors/ParslJobStatusOutputSummary.tla
```

`ParslJobStatusOutputReadError.tla` models the exception-policy mismatch between
`JobStatus.stdout` and `stdout_summary`/`stderr_summary`: the former catches every read error,
while the summaries currently catch only `FileNotFoundError`. TLC finds the three-state current
counterexample for a permission error; the fixed branch normalizes it to no output. The runtime
probe patches `open()` to raise `PermissionError` and checks both properties.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputReadErrorCurrent.cfg models/executors/ParslJobStatusOutputReadError.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputReadErrorFixed.cfg models/executors/ParslJobStatusOutputReadError.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_job_status_output_read_error_runtime.py -v
```

`ParslHtexManagerDrain.tla` models `Interchange.expire_drained_managers`. A present draining
manager with no tasks receives the drained reply and is removed from both bookkeeping sets. The
current configuration exposes the unchecked `_ready_managers[manager_id]` lookup when an
interesting set contains a stale manager ID; the fixed configuration ignores that ID. The runtime
probe reproduces the current `KeyError` and checks the normal drain path.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerDrainCurrent.cfg models/executors/ParslHtexManagerDrain.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerDrainFixed.cfg models/executors/ParslHtexManagerDrain.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerDrainPresent.cfg models/executors/ParslHtexManagerDrain.tla
```

`ParslHtexMonitoringMessage.tla` covers a manager result batch containing a monitoring payload.
With monitoring enabled the payload is forwarded; the current disabled-monitoring path asserts
that a radio exists and can crash, while the fixed path ignores the optional payload without
changing task bookkeeping. The runtime probe sends the real pickled multipart message.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringMessageCurrent.cfg models/executors/ParslHtexMonitoringMessage.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringMessageFixed.cfg models/executors/ParslHtexMonitoringMessage.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringMessageEnabled.cfg models/executors/ParslHtexMonitoringMessage.tla
```

`ParslHtexUnknownManagerMessage.tla` checks the identity guard before processing manager traffic:
unknown heartbeat and result messages are ignored without a reply, task update, or ready-manager
mutation; registration remains the only message that can create a manager record. Runtime probes
exercise both unknown heartbeat and unknown result messages.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexUnknownManagerHeartbeat.cfg models/executors/ParslHtexUnknownManagerMessage.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexUnknownManagerResult.cfg models/executors/ParslHtexUnknownManagerMessage.tla
```
