# Plan for the Parsl TLA+ Abstraction

## Basis and scope

The first version uses the Parsl paper's DataFlowKernel architecture and HTEX execution path
as the conceptual baseline, and the current upstream source as the behavioral reference. The
paper describes component relationships at a high level; source behavior takes precedence when
the two differ.

The primary configuration is:

```text
DataFlowKernel -> HighThroughputExecutor -> Interchange -> Manager/worker pool
               -> ExecutionProvider
```

Other executors can reuse the same abstract submission boundary, but are not modeled in full
in the first version.

## Completed phases

### 1. Behavioral baseline

The source audit covered:

- DFK task states, dependency counting, Future unwrapping, dependency-failure propagation,
  memoization, executor submission, retries, and completion callbacks.
- HTEX client-to-interchange queues, manager capacity, registration, heartbeats, result return,
  and manager loss.
- Provider `submit/status/cancel`, block lifecycle, and scaling parameters.
- DataManager as the boundary for data readiness/staging.

### 2. Executable safety model

The model uses finite sets for tasks, executors, workers, dependencies, retry count, and block
capacity. Python callables, Futures, serialized payloads, and wall-clock time are abstracted.

The central design choice is to keep logical tasks and physical attempts separate:

```text
Task A
 ├── Attempt(A, 0)
 ├── Attempt(A, 1)
 └── Attempt(A, 2)
```

The model includes task/Future state, dependency gating, executor assignment, worker binding,
provider allocation and failure, scale-in, memoization, data readiness, retries, timeout,
worker loss, executor loss, stale results, final-result acceptance, and an abstract
serialize/send/receive/decode path for task messages before worker dispatch.
Worker result messages use the same abstract lifecycle before a Future is resolved, including
the possibility that a failed attempt's late result is rejected as stale.
Task payloads now distinguish callable serializability from argument/closure serializability;
an unencodable payload fails before worker dispatch and follows the bounded retry path.
The data path now distinguishes input stage-in from output stage-out and records a transferred
content token for declared output files.
`ParslInputCorruption.cfg` adds a bounded damaged-stage-in path; `FileStagingSafety` prevents a
dependent task from consuming an input until repair returns it to `available`.
The bounded `ParslTime.cfg` model adds logical ticking, heartbeat age, attempt start time, and
timeout guards so TLC can explore timing-dependent worker loss and retry behavior.
`ParslTimeoutTerminal.cfg` covers the terminal timeout case when no retries remain.
`ParslMonitoring.cfg` adds a focused asynchronous monitoring/database status model with a
monotonic per-task write version, and checks that persisted terminal statuses never precede the
corresponding Future outcome. `MonitoringWriteFailure` models a transient write error and
requires a later publish to recover the current view.
`ParslSubmitFailure.cfg` adds a focused executor/provider boundary model in which an active
provider block does not imply that the executor accepts a new task submission.
`ParslProviderFailure.cfg` covers an active block becoming failed, clearing capacity, and
requesting a replacement block without producing a negative target count.
`ParslScaleIn.cfg` covers multi-block scale-in: cancelling one idle block preserves provider
activity and cancelling the final block clears provider capacity. It also covers a failed
secondary allocation while an earlier block remains active, plus cancellation of a pending
allocation before it becomes active. `ParslMinBlocks.cfg` checks that scale-in respects a
non-zero `MIN_BLOCKS` floor.
`ParslLocalExecutor.cfg` adds a provider-free `local` executor path while retaining the common
serialization, worker binding, and result protocol; local workers start idle without manager
registration.
`ParslMessaging.cfg` adds explicit bounded task/result wire queues and serialized-envelope
states, with `MessageSafety` checking that transport progress cannot bypass encoding or decode.
The result path now separates receive, acknowledgement, and consume/decode so duplicate delivery
after acknowledgement remains correlated with the same physical attempt. `ProtocolProgress`
uses a separate strong-fairness condition so duplicate/discard traffic cannot starve ACK/decode.
Its object-graph constants model callable, argument, closure, and nested referenced objects;
`ObjectGraphSafety` checks that a valid envelope cannot contain an unencodable object.
The graph check covers two bounded reference levels, and `ParslNestedSerialization.cfg`
exercises a non-serializable grandchild object in a closure-like payload.
Result encoding is modeled separately through `task:result`; `ParslResultSerializationFailure.cfg`
checks that an unencodable worker return follows retry/rejection without resolving its Future.
`ParslMessageLoss.cfg` adds bounded task/result transport loss and checks cleanup plus retry
behavior after a message is dropped.
`ParslMessageDuplicate.cfg` adds receiver-side duplicate delivery and explicit discard before
decode, preventing a duplicate envelope from resolving a Future twice.
`ParslFileContent.cfg` adds a deterministic symbolic content token for output files and checks
that stage-out transfers the token only after successful task completion.
The transfer is split into two bounded chunks (`stageout_chunk1` and `stageout_chunk2`) so that
the model cannot mark an output `transferred` until the complete protocol has progressed. A
corrupted first or second chunk has a distinct state and repair restarts from the damaged chunk.
`ParslFileCorruptionSmall.cfg` adds a minimal corrupted-output and repair/retransfer path;
the larger three-task corruption configuration is retained for future state-space reduction.
`ParslJoinInvalid.cfg` covers the `join_app` type-error branch. `SpecFair` now uses strong
fairness for logical/attempt progress so duplicate-message discard loops cannot starve work.
Successful joins carry a distinct `join-result` marker, while `JoinSafety` still requires every
inner Future to be resolved before the outer Future can succeed. `JoinResultSafety` additionally
requires the complete inner-Future observation set before an aggregate result is exposed, while
`JoinHandleSafety` distinguishes the intermediate handle from the final aggregate. `JoinFailureSafety`
requires outer rejection to be caused by a rejected inner Future.
`ParslRegistration.cfg` adds explicit HTEX manager registration before a worker can receive
dispatches or emit heartbeats.
`ParslRegistrationFailure.cfg` explores manager startup failure before registration and checks
that no worker binding is created from the failed manager.
`ParslRegistrationRecovery.cfg` adds reconnect/re-registration from a failed manager while
preserving the unregistered gate before dispatch.
`ParslStrategy.tla` is a separate small model of the source strategy policy: task pressure versus
available slots, bounded scale-out, minimum-block floors, and idle-timeout scale-in. It is kept
separate from the DFK protocol state machine so TLC can isolate scaling-policy counterexamples.
`ParslZMQ.tla` adds a focused multipart transport abstraction with explicit header/body encoding,
bounded queues, endpoint identities, disconnect/drop, reordering, duplicate delivery, route
validation, and acknowledgement. The configuration is intentionally small so transport traces
can be inspected before merging these states into the larger DFK model.
`ParslPython.tla` adds a callable-content abstraction with separate function, global, default,
closure, argument, and nested-object roots. It checks graph traversal before symbolic pickle
creation and graph traversal again during worker-side reconstruction, including a deliberately
unserializable nested-object configuration.
`ParslFileBytes.tla` adds bounded symbolic byte chunks, checksums, temporary buffers, corruption
repair, source-version changes during stage-in, and atomic stage-in/stage-out publication.
`ParslStageOutFuture.tla` refines output stage-out into separate-task, in-task, and no-staging
paths, including stage-out failure/retry and dependent-task gating on the output `DataFuture`.
`ParslClock.tla` separates wall-clock ticks, heartbeat transport and expiry, attempt start/deadline
timestamps, retry selection after timeout or manager loss, and stale late-result delivery. A
zero-retry configuration checks the terminal timeout path explicitly; lost attempts can now retry
after manager recovery while their late results remain stale.
`ParslHeartbeatBoundary.tla` checks the strict HTEX expiration inequality, heartbeat reset ordering,
and conversion of a manager's in-flight tasks into failure reports at expiry.
`ParslMonitoringDB.tla` models the asynchronous monitoring radio queue, bounded event versions,
database write failure/retry, queue reordering, stale-event suppression, and terminal-record
stability.
`ParslMonitoringDeferred.tla` models the DB manager's deferred first worker-task message, replay
after TASK/TRY insertion, duplicate-first replacement, and foreign-key ordering.
`ParslMonitoringDBInsert.tla` refines the concrete STATUS-table insert boundary: the actual
non-idempotent duplicate-key path is exposed as a dropped monitoring event, while the fixed
configuration checks an idempotent duplicate handler. This is based on the current
`DatabaseManager._insert` exception handling and the STATUS primary key in
`parsl/monitoring/db_manager.py`.
`ParslExecutorProvider.tla` models the HTEX executor/provider boundary: block request outcomes,
manager registration, worker readiness, submit admission, draining/recovery, provider failure,
and scale-in cleanup of queued/running tasks.
`ParslJoinApp.tla` models bounded `join_app` semantics for single/list/empty/invalid returns,
inner Future observation, ordered aggregate results, join-handle lifetime, and inner-failure
propagation. Inner retry policy remains below this join protocol, as in Parsl's callback path.
`ParslJoinDuplicates.tla` preserves list positions and duplicate Future references, checking that
`[f1, f1, f2]` yields a duplicate ordered result and that repeated failed references contribute
the corresponding multiplicity to `JoinError`.
`ParslJoinMixedList.tla` adds the concrete mixed-list validation branch: only all-Future lists are
registered for callbacks, while `[Future, non-Future]` fails immediately and an empty list
completes without callbacks.
`ParslJoinRetry.tla` adds physical inner attempts and verifies that retryable inner failures remain
unresolved to the outer join until a final attempt succeeds or fails.
`ParslNestedJoin.tla` adds a nested join layer and checks that leaf completion/failure propagates
through the nested handle before the outer join can complete.
`ParslTaskTransport.tla` connects object-graph serialization to task/result transport, including
envelope corruption, decode rejection, dispatch gating, worker loss, retry correlation, and stale
result suppression.
`ParslHtexResultQueue.tla` probes the concrete HTEX result queue worker, including valid and
exception result decoding, malformed/duplicate messages, interchange failure, and Future orphaning
when the current pop-before-validation path exits the worker.
`ParslHtexVersionMismatch.tla` models manager registration version rejection, the queued fatal
`task_id=-1` result, and the admission window before the result thread sets executor bad state.
`ParslHtexDispatchPriority.tla` models the HTEX `SortedList` priority order (`-priority`,
`-task_id`), manager capacity, draining/recovery admission, completion release, and in-flight
cleanup on manager failure.
`ParslProviderPolling.tla` refines provider behavior into submit/status/cancel calls, transient API
errors, unknown status, cancellation rollback, and bounded polling/failure windows.
`ParslExecutorKinds.tla` adds a contract matrix for provider-free thread execution and
provider-backed HTEX/MPI/workqueue paths, including manager registration, resource-request
rejection, admission, drain/recovery, and provider/executor failure cleanup.
`ParslMPISpec.tla` refines the MPI path with resource-specification key validation, derived
`num_ranks`/`ranks_per_node`, zero-node admission probing, and the positive-node candidate fix.
`ParslExecutorShutdown.tla` refines concrete shutdown behavior: ThreadPool waits for accepted
work, WorkQueue's collector fails tasks left behind during process shutdown, and HTEX closes its
interchange before in-flight cleanup. It also checks that shutdown rejects new submissions.
`ParslWorkQueueResults.tla` refines WorkQueue's collector result protocol: valid result files,
deserialization failures, app exceptions, no-result reports, and final cleanup of outstanding
tasks when the collector exits.
`ParslFluxResult.tla` refines FluxExecutor's wrapped Future, result-file decoding, abnormal exit,
and cancellation propagation; its actual configuration preserves a cancellation-orphan probe and
the fixed configuration checks the candidate propagation fix.
`ParslTaskVineResults.tla` refines TaskVine's manager report and collector protocol, including
result-file failure mapping and cleanup of all outstanding Futures after manager failure.
`ParslRadicalPilotResults.tla` refines RadicalPilot callback mapping for Bash/Python/MPI tasks,
master failure propagation, cancellation, and the shutdown pending-Future probe.
`ParslGlobusComputeConfig.tla` refines Globus Compute's temporary per-submit resource configuration
and records the caller-side serialization assumption needed to avoid cross-submit interference.
`ParslProviderKinds.tla` refines concrete provider behavior for Slurm-like and Kubernetes-like
backends: submit/status/cancel outcomes, backend-to-Parsl state translation, missing jobs,
unknown status, timeout distinction, cancellation failure, and CPU-per-task admission.
`ParslAWSProviderStatus.tla` adds EC2-specific pending/running/terminated mapping and a missing
instance response probe with a candidate terminal completion fix.
`ParslPBSProSubmit.tla` models the PBS Pro `qsub` success/empty-output boundary. The actual
configuration exposes a `None` job identifier with no registered resource; fixed and non-empty
output configurations check the provider/executor submission contract.
`ParslTorqueStatus.tla` models Torque's qstat parser when a status line names a job outside the
provider's resource map. The actual configuration exposes the direct dictionary-indexing crash;
the fixed configuration ignores foreign scheduler lines, matching the safer LSF-style guard.
`ParslCondorStatus.tla` models Condor status parsing for truncated scheduler output. The current
two-field indexing path can crash on a malformed line; the fixed configuration skips short lines
and preserves the previously known resource status.
`tests/test_serialization_runtime.py` exercises the current serialization facade against real
closures, callable/data headers, three-part apply-message packing, and a deliberately failing
object graph. It complements the finite TLA+ serialization-wire models with runtime evidence.
`tests/test_zip_file_transfer_runtime.py` executes the local `ZipFileStaging` byte path against
real temporary files, including archive corruption before output publication. It complements the
chunk/checksum and stage-out Future TLA+ models with concrete content evidence.
`tests/test_htex_heartbeat_runtime.py` drives the current `Interchange.expire_bad_managers` method
with deterministic time and fake output transport, checking the strict threshold and serialized
manager-loss reports without starting a real worker process.
`tests/test_zmq_serialization_runtime.py` connects real in-process ROUTER/DEALER and PAIR sockets
to Parsl's apply-message serialization, checking multipart framing, route identity, payload
deserialization, execution, and acknowledgement.
`tests/test_monitoring_db_runtime.py` uses a temporary SQLite database to validate the concrete
STATUS primary-key collision and the current `DatabaseManager._insert` generic-exception path
that rolls back and silently drops the duplicate event.
`tests/test_join_runtime.py` runs the actual `join_app` callback protocol on a local thread
executor, covering single Futures, ordered duplicate references, empty lists, `JoinError`,
nested joins, scalar-return rejection, and mixed-list rejection.
`tests/test_retry_timeout_runtime.py` runs a retryable app and a walltime-limited app on the
real thread executor, confirming distinct physical attempts and terminal `AppTimeout` behavior.
`tests/test_memoization_runtime.py` runs duplicate and distinct cached calls plus a dependent app,
checking the real BasicMemoizer result path and execution count.
It also covers Slurm suspended/requeued mappings (`HELD`/`PENDING`) and executor-driven
`SCALED_IN` terminal cleanup with terminal-state invariants.
`ParslProviderStatusBatch.tla` models bounded scheduler status batches, atomic application of
successful output, and preservation of the prior status map when a scheduler command fails or
times out; missing Slurm jobs follow the current `COMPLETED` fallback behavior.
`ParslKubernetesPolling.tla` is a bug-finding probe for Kubernetes API read failures. Its actual
configuration reproduces the source's `is JobStatus(...)` identity-check behavior and yields a
counterexample in which a running pod remains `RUNNING` after a read error; the value-based fixed
configuration proves the intended `UNKNOWN` transition.
`ParslProviderExecutorBridge.tla` connects provider job observations to executor admission,
manager registration, worker capacity, unknown-status tolerance, and terminal cleanup of queued
and running work. It now covers terminal provider failure both before manager registration and
after a manager has become active.
`ParslHeartbeatProvider.tla` separates transient provider `UNKNOWN` status from HTEX manager
heartbeat expiry, and checks manager reconnect plus loss accounting after heartbeat timeout.
`ParslResultRace.tla` separates physical attempt result production from callback delivery and
checks retry selection, late success/failure races, stale callback suppression, and one-time
Future resolution.
`ParslJoinCallbackRace.tla` models the actual `join_app` callback gate: early callbacks return
without finalizing, the final callback checks all inner Futures under a lock, failures become
`JoinError` only after all selected Futures are done, and duplicate callbacks are harmless.
`ParslJoinMemoData.tla` connects joins to memoization and DataFuture readiness: cached inner
Futures complete without executor attempts, staged file Futures remain unresolved until transfer
readiness, and the outer join cannot finalize early.
`ParslJoinMonitoring.tla` connects join status events to the asynchronous monitoring radio and
database, preserving join/data invariants across event reordering, write failure/retry, and
terminal-record protection.
`ParslResourceAdmission.tla` models WorkQueue-style cores/memory/disk/GPU resource validation and
worker capacity accounting, with a companion autolabel configuration for partial specifications.
`ParslResourceScaling.tla` connects per-task core demand to strategy scale-out, pending allocation
success/failure rollback, capacity-guarded dispatch, retryable pressure, and minimum-block scale-in.
`ParslPollerBadState.tla` models the `JobStatusPoller.poll` ordering: provider status refresh,
`FAILED`/`MISSING` error-threshold handling, executor bad-state transition, failure of outstanding
tasks, and suppression of later admission or scale-out.
`ParslSerializationWire.tla` models concrete callable/args/kwargs serialization headers, decimal
length framing, ordered unpack/decode, serializer failure, and corrupt-frame rejection before
dispatch.
`ParslSerializationZMQBridge.tla` connects those frames to task/result transport, route checking,
attempt correlation, duplicate/drop handling, worker-loss retry, and stale-result suppression.
`tools/cloudpickle_fixture.py` provides a real Python/cloudpickle observation for the symbolic
object-graph model, including a successful closure round trip and a lock-containing closure that
raises a serialization error. The recorded bytes/digest are explicitly versioned observations.
`ParslIdleManagerTimeout.cfg` covers heartbeat expiry for an idle registered manager and clears
the associated provider/executor capacity. `ParslMultiManagerTimeout.cfg` refines this to
multiple managers sharing an executor, preserving remaining capacity after one manager expires.
`ParslExecutorDrain.cfg` models an executor entering `draining`, rejecting new submissions while
allowing existing attempts to finish, followed by explicit recovery.
`MessageCorrelationSafety` now checks that queued, received, duplicate, and consumed envelopes
remain associated with their logical task and retry attempt.
`ParslMisroute.cfg` explores decoded work offered to the wrong executor manager and checks that
the protocol rejects it before worker execution.
`ParslResultMisroute.cfg` applies the same executor-source check to result envelopes before
Future resolution.

### 3. Checked properties

The safety configurations check:

1. `TypeOK` for all finite domains and state mappings.
2. Dependency safety: a task cannot run before all dependency Futures resolve.
3. Terminal-state stability: a completed logical task remains resolved.
4. Retry bounds.
5. One-at-a-time worker capacity and bidirectional worker/attempt binding.
6. Valid executor/worker assignment for running attempts.
7. Attempt identity and Future result consistency.
8. Stale-result safety: an old attempt cannot overwrite a newer logical result.
9. Wire/envelope safety: task and result messages cannot skip serialization, transport, or
   decode states, and failed attempts cannot leave a deliverable result envelope behind.

The no-failure configuration adds `EventuallySettled` under `WF_vars(NextCore)` fairness.

## Planned extensions

After the MVP is stable, possible extensions are:

- richer DataManager/staging behavior, including stage-in/stage-out failure and checksums;
- bounded message reordering and message correlation IDs;
- richer `join_app` behavior beyond the bounded inner-Future set and invalid-return branch now modeled;
- manager heartbeat timeout, version mismatch, drain, and richer executor bad-state transitions;
- monitoring as an abstract eventual event stream;
- dynamic task creation while a workflow is running;
- additional executor/provider-specific models.

## Validation workflow

Each meaningful stage should have its own commit and TLC configuration. The repository should
retain normal-success, memoization-hit, retry-success, permanent-failure, provider-failure,
worker-loss, scale-in/out, and late-result scenarios. For each safety property, a deliberately
broken variant can be added later to ensure TLC produces a counterexample.

The model is intentionally a bounded protocol abstraction. A passing TLC run means that the
specified finite abstraction satisfies the listed properties; it does not prove that every
implementation detail of Parsl is correct.
