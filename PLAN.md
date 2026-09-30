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

### Recent cross-layer refinements and regression baseline

The latest app-boundary refinement adds `ParslBashAppOutcome`: shell exit status, stdout side
effects, declared-output validation, and Future success/failure are modeled as separate phases.
The real `bash_app` bridge confirms that non-zero exits become `BashExitFailure`, while successful
apps resolve only after declared output files exist.

The provider-boundary refinement adds `ParslLocalProviderExitStatus`, connecting the local
provider's `.ec` marker, process liveness, cancellation flag, and cached terminal status. TLC and
the runtime bridge confirm that numeric exit markers take precedence over cancellation/liveness.

The ThreadPool refinement adds `ParslThreadExecutorFutureLifecycle`, modeling queued-versus-running
Future cancellation and shutdown waiting. A real one-worker executor confirms that queued work can
be cancelled while a running callable continues to completion.

The serialization refinement adds `ParslApplyDispatchBoundary`, connecting length-prefixed facade
unpacking to worker-side `execute_task` arity. The current model exposes malformed extra frames at
the worker boundary; the fixed branch rejects them immediately after framing.

The timeout refinement adds `ParslHtexShutdownTimeout`, covering HTEX terminate/wait/kill ordering
and pipe closure after a shutdown deadline. A real executor shutdown with a process double confirms
that kill follows `TimeoutExpired` before outgoing and command pipes are closed.

The join refinement adds an end-to-end cancelled-inner-Future bridge. The current model and real
`join_app` path reproduce the callback exception that leaves the outer Future in `joining`; the
fixed branch maps cancellation into a terminal join failure.

The same bridge now covers list-valued joins: a successful member plus a cancelled member reaches
the same non-terminal callback path in the current implementation, matching
`ParslJoinListCancellation` and its fixed terminal-failure branch.

The data-readiness model is now part of the repeatable recent-model sweep: source-version changes
during bounded stage-in produce a current stale-publication counterexample, while the fixed branch
retries before admitting the dependent task. Existing runtime probes verify actual binary bytes and
dependency blocking through `DataFuture`.

The monitoring retry/high-water model is now in the same sweep. Its current branch permits an old
attempt event to overwrite a newer database view; the fixed branch preserves terminal status and
version monotonicity, complementing the real SQLite status-history bridge.

The HTEX protocol baseline now includes `ParslHtexTaskMessageMalformed`: malformed decoded task
objects produce a current interchange-crash counterexample, while the fixed branch discards them
and keeps the task-incoming loop alive. The existing runtime probe uses the real interchange
message-processing method.

The matching result direction is now in the smoke sweep through `ParslHtexResultMessageMalformed`:
the current branch aborts on a corrupt pickle frame, while the fixed branch ignores that frame and
continues to forward a later valid result.

HTEX task admission now also has repeatable priority/resource-shape checks: current models expose
the `TypeError`/`AttributeError` paths for non-numeric priority and non-mapping resource specs,
while fixed models reject both before queue insertion. Their real interchange probes remain the
runtime counterparts.

Provider coverage now includes the AWS status-cardinality boundary: when EC2 omits a requested
instance, the current model returns no status, while the fixed branch returns one explicit
`UNKNOWN` observation. The real provider probe exercises the same missing-instance response.

Kubernetes polling is now also in the sweep: a pod-read error leaves a running job falsely
`RUNNING` in the current identity-comparison path, while the fixed branch exposes `UNKNOWN`.
The mock Kubernetes API runtime probe verifies the same error translation.

Slurm scheduler polling is now included as well: a truncated non-empty status record crashes the
current batch parser, while the fixed branch skips that record and retains known job state. The
real parser probe covers the same malformed line.

PBS Pro polling is now included alongside Slurm: malformed qstat JSON crashes the current parser,
while the fixed branch preserves the last known job status. The real PBS Pro parser probe confirms
the same failure boundary.

Condor polling is now included as well: a successful `condor_q` command containing a truncated
record crashes the current parser, while the fixed branch ignores it and preserves known state.
The real Condor parser probe covers that malformed line.

Grid Engine polling now has a repeatable duplicate-record check: removing the same job twice
crashes the current `jobs_missing` bookkeeping, while the fixed branch makes duplicate records
idempotent. The real qstat parser probe exercises that duplicate line.

Torque submit coverage now includes normal qsub registration plus empty-output and non-zero-command
failure paths. The bounded model checks that only a parsed job ID creates a pending resource, and
the real submit-script probes cover all three outcomes.

Work Queue submit coverage now includes both process-admission and serialization failures. The
current branch leaves a pending Future/task-map entry orphaned in each case; fixed configurations
roll the mapping back, matching the real Work Queue submit probes.

TaskVine submit coverage now mirrors those two failure paths. The current model leaves a mapped
pending task after process or serialization failure; the fixed configurations remove it, matching
the real TaskVine submit probes.

Flux executor cleanup now joins the smoke sweep: a cancelled first Future makes the current
`_error_out_jobs` drain abort and strand a later pending Future; the fixed branch skips terminal
entries and continues draining, matching the real cancellation probe.

Poller shutdown/scale-in is now included too: the current timeout close can scale in while a status
callback is still running, while the fixed branch requires callback quiescence before scale-in.
The real `JobStatusPoller.close` runtime probe exercises that race.

HTEX duplicate manager registration is included as well: the current interchange path replaces an
existing manager record and can discard its in-flight task list, while the fixed branch preserves
ownership until recovery or completion. The matching runtime probe drives two registration frames
through the real `Interchange.process_manager_socket_message` path.

The smoke sweep also covers stale IDs during HTEX drain cleanup. The current
`expire_drained_managers` path can index a manager removed by another cleanup path and abort the
poll; the fixed branch ignores the stale ID while preserving the normal drained-manager removal
and acknowledgement behavior.

The HTEX watchdog/result publication race is also in the smoke sweep. The current worker path can
queue success before removing its in-progress mapping, allowing the watchdog to enqueue a second
`WorkerLost` result; the fixed branch treats an already-published result as terminal.

Radical-Pilot bulk shutdown is now covered too. The current collector exits as soon as the
termination flag is set and can leave a queued Future pending; the fixed branch drains or
explicitly completes queued work before collector exit.

AWS provider polling now has a focused stale-instance case: an EC2 observation absent from the
local resource map crashes the current status path, while the fixed branch converts it to an
explicit `UNKNOWN` observation and keeps polling.

The command-client close race is now in the smoke sweep: the current `CommandClient.close()`
terminates the socket while leaving the health flag true, so a later `run()` touches a closed ZMQ
socket; the fixed branch rejects the command before transport use.

Kubernetes admission is now covered alongside polling: the current submit path records a newly
created Pending pod as `RUNNING`, allowing task admission too early; the fixed branch keeps the
job Pending until a poll observes the Running phase.

Callable serialization coverage now includes equal-but-distinct Python objects: the current
`DillCallableSerializer` cache can reuse the first payload when custom equality and hashing collide;
the fixed branch requires identity/content-sensitive cache behavior.

Zip stage-in write-failure coverage is now in the smoke sweep: the current path writes directly to
the final destination and exposes partial bytes after a failure; the fixed branch writes to a
temporary path and publishes only after the complete member is available.

Monitoring update retention is now in the smoke sweep: the current `_update` path can swallow a
permanent database error after the batch has been drained, while the fixed branch retains the
message for a later retry or explicit dead-letter decision.

Globus transfer timeout coverage is now in the smoke sweep: repeated per-poll timeouts can leave
an `ACTIVE` transfer pending forever in the current path; the fixed branch turns the bounded poll
budget into an explicit terminal timeout.

`join_app` duplicate-failure aggregation is now in the smoke sweep: a repeated reference to the
same failed inner Future must contribute one `JoinError` dependency entry per list position; the
fixed branch preserves that multiplicity and order.

Azure status bookkeeping is now included: the current provider returns a translated `RUNNING`
status without updating its local resource entry, while the fixed branch keeps returned and local
state consistent for subsequent polling and scaling decisions.

AWS cancellation cleanup is now covered: after a successful remote terminate, the current path can
raise on a stale local instance/resource ID; the fixed branch treats missing local bookkeeping as
an idempotent successful cancellation.

Azure provisioning rollback is now covered: the current submit path can leave instance and
resource bookkeeping after a post-creation disk/start/worker-command failure; the fixed branch
rolls back partial local state before reporting the setup error.

LocalProvider submit cleanup is now covered: a failed launcher can leave the generated worker
script and partial resource state in the current path; the fixed branch removes newly-created
artifacts before surfacing the launch failure, while the success path retains the script/resource.

Globus Compute submit concurrency is now in the smoke sweep: the current wrapper mutates one shared
SDK executor during override/submit/restore, so overlapping calls can observe another task's
resource specification; the fixed branch serializes that critical section.

LSF duplicate status handling is now in the smoke sweep: duplicate `bjobs` lines crash the current
`jobs_missing` bookkeeping, while the fixed branch makes removal idempotent and preserves the
polling pass.

Timer close quiescence is now in the smoke sweep: the current timeout close returns a completed
looking result while its callback thread remains alive; the fixed branch exposes an explicit
closing/timeout outcome until callback quiescence.

Mutable `join_app` list aliasing is now in the smoke sweep: the current callback observes caller
mutation and can complete with an empty or shortened result, while the fixed branch snapshots list
membership at join registration. A stable no-mutation configuration remains covered as a baseline.

Command send retry coverage is now included: the current `CommandClient.run` ignores its
`max_retries` argument after a send exception, while the fixed branch consumes a bounded retry
budget before returning a terminal send error or accepting a reply.

TaskVine duplicate-report handling is now in the smoke sweep: a late manager report currently
raises `KeyError`, exits the collector, and causes unrelated pending Futures to fail; the fixed
branch ignores stale IDs and keeps collecting independent reports.

Work Queue duplicate-report handling is now covered in parallel: the current collector has the same
stale-ID `KeyError` and unrelated-Future cleanup failure, while the fixed branch keeps the result
thread alive and ignores the duplicate report.

`ResultsIncoming` close/get behavior is now covered: the current wrapper can poll a terminated ZMQ
socket after close, while the fixed branch exposes a closed guard and returns a quiescent no-message
result.

Google Cloud cancellation bookkeeping is now covered: successful remote deletion currently leaves
the local resource `RUNNING`; the fixed branch marks it terminal, while a remote failure preserves
the running state and returns failure.

Monitoring TASK insert bookkeeping is now covered: the current path marks a task ID as inserted
before the SQL insert succeeds, so a later observation is misclassified as UPDATE; the fixed branch
records bookkeeping only after success and retries the failed insert path.

Recent focused models now connect the previously separate boundaries:

- `ParslFunctionObjectTransport` and `ParslCallableRetryTransport` model Python callable/closure
  snapshots across serialized ZMQ task frames, physical retries, and stale result correlation.
- `ParslFunctionObjectContents` is included in the smoke sweep as the smallest executable
  callable/argument object snapshot: post-pack mutation cannot change the worker result.
- `ParslSerializationWire` and its failure configuration are now in the smoke sweep, checking
  the concrete `C2`/`02` headers, length framing, ordered unpack/decode, and rejection before
  dispatch when one buffer is not serializable.
- `ParslMessageLoss` and `ParslMessageDuplicate` are now in the smoke sweep, connecting bounded
  transport loss/duplicate delivery to retry, correlation, cleanup, and terminal-result safety.
- `ParslMisroute` and `ParslResultMisroute` are now in the smoke sweep, rejecting task/result
  envelopes delivered through the wrong executor-manager binding.
- `ParslProviderFailureRetry` is now in the smoke sweep, separating logical task retry from lost
  provider attempts and rejecting late results from stale physical attempts.
- `ParslKubernetesUnknownJob` is now in the smoke sweep, requiring stale job IDs to return an
  explicit UNKNOWN status instead of raising from local resource bookkeeping.
- `ParslAWSProviderSubmit` is now in the smoke sweep, checking EC2 launch success/failure,
  empty launch responses, and resource registration consistency.
- `ParslCondorStatusFailure` is now in the smoke sweep, requiring failed `condor_q` commands to
  preserve the last resource state instead of parsing stale or malformed stdout.
- `ParslCondorUnknownJob` now adds the stale local-ID boundary to the smoke sweep, contrasting
  the current `KeyError` with an explicit UNKNOWN status path.
- `ParslGridEngineStatusBatch` now adds malformed-record continuation to the smoke sweep, keeping
  a later valid qstat record observable in the fixed parser.
- `ParslPBSProJobIdAlias` now adds short/qualified job-id normalization to the smoke sweep,
  including duplicate alias handling and the unique-id control path.
- `ParslPython`, `ParslPythonFailure`, and `ParslPythonCyclic` are now in the smoke sweep,
  traversing callable roots, globals/defaults/closures, nested arguments, failed object graphs,
  and self-referential cycles with visited-set protection.
- `ParslPythonTimeoutCatch` is now in the smoke sweep, checking that a Python app cannot turn an
  injected walltime timeout into a successful Future by catching the timeout exception.
- `ParslFunctionObjectTransport`, `ParslObjectSnapshotRetry`, and `ParslZMQObjectSnapshot` now
  extend that boundary through queued frames and physical retries, including current/fixed
  stale-payload counterexamples.
- `ParslFileBytes` is corroborated by a real binary Zip stage-out/stage-in probe with per-chunk
  SHA-256 checksums.
- `ParslFileTransferRetry` is now in the smoke sweep, checking that source mutation during
  stage-out makes the first publication stale and forces a version-matching retry.
- `ParslDataFutureTransfer` is now in the smoke sweep, connecting producer completion, chunk
  checksums, atomic stage-out publication, DataFuture readiness, and consumer admission.
- `ParslHTTPStatusValidation` now joins the staging sweep, checking that non-2xx response bodies
  cannot be published or passed to a task, while preserving the successful 2xx path.
- `ParslRsyncPartialCleanup` now joins the staging sweep, checking that a failed transfer removes
  partial destination bytes before reporting failure; `tests/test_rsync_partial_cleanup_runtime.py`
  exercises the current leftover-file behavior.
- `ParslStageOutFuture` now joins the sweep for separate-task, in-task, and no-staging modes,
  checking output publication and dependent-task gating against the real DataFuture tests.
- `ParslGlobusTransferFailure` is now in the smoke sweep, distinguishing terminal transfer
  failure reporting from missing diagnostic events and successful event-bearing completion.
- `ParslClusterSubmitScript` is now in the smoke sweep for a concrete provider boundary: valid
  template publication, missing scheduler arguments, and script-path I/O failure remain distinct.
- `ParslTimeLimitedOpenTimeout` is now in the smoke sweep, separating a genuine file open from
  a missing-file timeout and preventing a raw `open()` after the timeout horizon.
- `ParslHeartbeatClockRollback` is now in the smoke sweep, distinguishing wall-clock rollback
  from monotonic heartbeat age so manager expiry is not delayed indefinitely.
- `ParslClusterStatusRequest` is now in the smoke sweep, checking one backend poll, duplicate
  request-position preservation, and ordered public status projection.
- `ParslMonitoringUpdatePersistentRetry` is now in the smoke sweep, exposing unbounded
  `OperationalError` retries in `_update` and a bounded fixed branch with an explicit abort.
- `ParslMonitoringPersistentRetry` now covers the matching `_insert` loop, with a bounded fixed
  retry budget and explicit aborted-write state; the runtime bridge uses an always-locked SQLite
  double to verify the current non-terminating behavior.
- `ParslMonitoringBatchAtomicity` now joins the sweep, checking that a duplicate STATUS row does
  not discard valid sibling events; the SQLite batch probe records the current rollback behavior.
- `ParslMonitoringWorkflowInsertBookkeeping` now joins the sweep, requiring workflow bookkeeping
  to be recorded only after a successful WORKFLOW row insert.
- `ParslMonitoringWorkflowEndBookkeeping` now covers the matching failed end-update path, requiring
  a retryable failed update rather than permanently marking workflow completion.
- `ParslMonitoringLastMessageRace` now joins the sweep, checking that a last worker message is
  deferred until its TRY row exists; `tests/test_monitoring_last_message_runtime.py` records the
  current ordering weakness.
- `ParslSlurmStatus` is now in the smoke sweep, checking that foreign scheduler job rows do not
  crash the status poll and that known resource state remains available.
- `ParslMonitoringZMQRouterFailure` is now in the smoke sweep, connecting the monitoring receive
  channel to a bounded failure-stop policy instead of retrying a permanently broken socket.
- `ParslHeartbeatTimeoutPersistence` combines strict HTEX heartbeat expiry, task timeout,
  late completion, and monitoring persistence.
- `ParslMonitoringStatusHistory` models append-only status rows and timestamp-derived latest state,
  with a real SQLite insertion/query bridge.
- `ParslProviderWorkerScaling` separates provider blocks from registered executor worker slots and
  is bridged to the real `BlockProviderExecutor` block/job mapping.
- `ParslJoinCallableTransport` combines serialized inner callable snapshots, retry attempts,
  stale results, and ordered duplicate positions in an outer `join_app`; a real Parsl runtime
  bridge exercises the same result shape.
- `ParslJoinMonitoring` is now in the smoke sweep, connecting memoized, staged, and ordinary
  inner Futures to versioned outer status events, reordered delivery, database-write retry, and
  terminal monitoring-record stability.
- `ParslJoinApp` and `ParslNestedJoin` are now in the smoke sweep, covering the core outer-handle
  protocol and delayed propagation from leaf Futures through an inner join into an outer join.
- `ParslHtexResultBatchContinuation` is now in the smoke sweep, requiring a malformed result
  frame to be discarded without aborting later valid results in the same manager batch.
- `ParslHtexExecutorResultFrameContinuation` extends that property to the executor result queue:
  a corrupt outer pickle cannot strand unrelated later Futures.
- `ParslHtexResultQueue` is now in the smoke sweep, checking Future/task mapping, malformed
  result handling, duplicate task IDs, and interchange failure without orphaning pending work.
- `ParslHtexManagerSelection` is now in the smoke sweep, checking random and block-ID manager
  selection orders without inventing or duplicating manager identities.
- `ParslHtexManagerEligibility` is now in the smoke sweep, separating selector order from
  dispatch admission and skipping inactive, draining, or zero-capacity managers.
- `ParslExecutorSelection` is now in the smoke sweep, requiring an empty executor selection to
  be rejected before `random.choice` can expose a raw `IndexError`.
- `ParslResourceAdmission` and its autolabel configuration are now in the smoke sweep, checking
  cores/memory/disk/GPU validation, queueing, capacity admission, and resource release.
- `ParslResourceScaling` is now in the smoke sweep, connecting task core demand to scale-out,
  pending allocation failures, dispatch capacity, and safe scale-in.
- `ParslDependencyTraversal` is now in the smoke sweep for shallow-vs-deep Future discovery,
  including list, dictionary value/key, tuple, and set containers.
- `ParslMemoFunctionIdentity` is now in the smoke sweep, checking that changed Python function
  source cannot reuse a stale memo key while unchanged source remains stable.
- `ParslMemoExceptionCheckpoint` is now in the smoke sweep, distinguishing in-memory failed-call
  reuse from checkpoint restart behavior and explicit failure persistence.
- `ParslMemoDictOrdering` is now in the smoke sweep, checking heterogeneous Python dictionary
  keys, canonical fixed ordering, and the homogeneous-key success path.

The runtime suite currently contains 485 probes and passes as a whole:

```bash
PYTHONWARNINGS=ignore PYTHONPATH=/tmp/parsl-source:/home/cc/tla-parsl \
  /tmp/parsl-venv/bin/python -m unittest discover -s tests -p 'test*_runtime.py' -q
```

The recent cross-layer TLC sweep is also clean on fixed/specification configurations:

| Model | Configuration | TLC result |
| --- | --- | --- |
| `ParslCallableRetryTransport` | `Fixed` | 190 generated / 73 distinct |
| `ParslHeartbeatTimeoutPersistence` | `Fixed` | 1,408 generated / 400 distinct |
| `ParslMonitoringStatusHistory` | normal | 150 generated / 53 distinct |
| `ParslProviderWorkerScaling` | normal | 73 generated / 24 distinct |
| `ParslJoinCallableTransport` | normal | 16,113 generated / 3,559 distinct |

The corresponding `Current` configurations for callable retry and heartbeat intentionally return
TLC exit 12 with their documented stale-result counterexamples.

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
content token for declared output files. `ParslFilePathResolution.tla` separately checks the
`File.filepath` resolution boundary: local file URLs, staging-provided `local_path` overrides,
and rejection of unstaged remote URLs.
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
`ParslEndToEnd.tla` is a compact integration model for the next refinement step: dependency
release, task serialization, wire delivery, worker execution, result delivery, retry/timeout,
and late-result correlation are represented in one short state machine. The current configuration
produces a `StaleResultSafety` counterexample, while `ParslEndToEndFixed.cfg` checks the stale
result guard successfully.
`ParslTimedHeartbeat.tla` combines logical time, heartbeat expiry, task deadlines, and late
results. Its current configuration permits a post-timeout result and violates `ResultSafety`; the
fixed configuration rejects the result as stale while preserving independent heartbeat and task
timeout transitions.
`ParslMonitoringDelivery.tla` connects logical status versions to an asynchronous event queue and
database record. Queue reordering exposes the stale-event overwrite in the current branch;
`ParslMonitoringDeliveryFixed.cfg` preserves the database version high-water mark.
`ParslJoinComplete.tla` consolidates the `join_app` cases into one state machine: single and list
returns, duplicate references, empty and invalid returns, `None` results, and inner cancellation.
The current branch's set-like duplicate handling violates `JoinResultSafety`; the fixed branch
preserves the returned sequence.
Both current and fixed configurations are now in the recurring smoke sweep, alongside the real
join callback, return-shape, cancellation, and aggregation probes.
`ParslSerializerRegistry.tla` models the concrete code/data serializer registries and their
code-first dispatch order. An identifier collision is a current-path counterexample and a fixed
path rejection; the runtime probe confirms the current facade behavior.
`ParslExecutorProviderLifecycle.tla` connects provider allocation and terminal cleanup to manager
registration, executor drain, worker-slot admission, and scale-in. Its fixed branch enforces the
provider `MIN_BLOCKS` floor.
`ParslZMQSerializationEndToEnd.tla` combines concrete serializer headers and multipart ZMQ
progress with worker-attempt correlation. Its current branch exposes wrong-attempt result
resolution; the fixed branch classifies those messages as stale.
It is now part of the recent smoke sweep, alongside the real in-process ROUTER/DEALER and
`pack_apply_message` bridge in `tests/test_zmq_serialization_runtime.py`.
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
`ParslDataFutureTransfer.tla` connects the concrete data-manager ordering to a bounded
producer, chunked stage-out, `DataFuture` readiness, and a blocked consumer. Its current
configuration exposes premature readiness after a partial transfer; the fixed configuration
requires an all-chunk atomic publish.
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
`ParslExecuteTask.tla` models the worker-side `execute_task` boundary after transport: a packed
apply message is decoded before invocation, user exceptions become failed execution results, and
malformed messages are rejected without invoking user code. `tests/test_execute_task_runtime.py`
checks the same behavior against the real executor helper.
`ParslAzureStatus.tla` adds the Azure VM status translation boundary, including short
`instanceView.statuses` lists during provisioning, known running/completed states, and explicit
unknown-state handling. `tests/test_azure_status_runtime.py` drives the real provider method with
fake Azure API objects.
`ParslAzureCancel.tla` models Azure VM cancellation, including linger mode, cloud-delete failure,
and the current `list.remove` race when a successful cloud deletion finds no local instance id.
The fixed configuration treats that idempotent bookkeeping case as cancelled.
`ParslThreadExecutor.tla` refines the provider-free thread executor: unsupported resource
specifications are rejected before task creation, accepted work survives `shutdown(wait=False)`,
and `shutdown(wait=True)` waits for the accepted task before becoming stopped. The runtime probe
extends `tests/test_thread_executor_runtime.py` with the non-blocking shutdown path.
`ParslZipStageIn.tla` refines zip-file stage-in with archive validation, output publication, and
write failure. The current path can leave a partial output after a failed direct write; the fixed
configuration represents temporary-file plus atomic publication. The runtime probe injects a
write failure into the real `_zip_stage_in` helper.
`ParslZipStageOut.tla` models the complementary archive append and source-removal ordering. A
successful archive write followed by failed source cleanup can be retried into duplicate archive
members; its fixed configuration models idempotent replacement. The zip runtime probe reproduces
the duplicate entry with a source-version change between attempts.
`ParslCommandClient.tla` models the HTEX REQ/REP command socket: a successful reply completes a
request, while a response timeout poisons the client and rejects later reuse. The runtime probe
uses a fake socket to exercise the real polling and error classes without a network daemon.
`ParslHtexManagerMessage.tla` models manager-to-interchange decode isolation: malformed multipart
or pickle input is ignored without changing manager heartbeat state, while a valid heartbeat
updates the timestamp and emits the heartbeat reply. `tests/test_htex_manager_message_runtime.py`
drives the real `Interchange.process_manager_socket_message` method.
`ParslGridEngineSubmit.tla` adds the missing Grid Engine provider submission model: submit-script
creation, qsub failure, empty successful output, and first-job-id registration. It corresponds to
the existing `tests/test_grid_engine_submit_runtime.py` probe.
`ParslSlurmStatus.tla` refines the Slurm batch status parser. The current configuration exposes a
`KeyError` when scheduler output names a foreign job ID; the fixed configuration ignores that line
while preserving local resources. `test_slurm_status_batch_runtime.py` now reproduces the current
exception alongside command-failure preservation and missing-job completion.
`ParslMonitoringDBRetry.tla` models the concrete `_insert` distinction between recoverable
SQLAlchemy `OperationalError` (rollback and retry) and integrity errors (rollback and drop). The
monitoring runtime probe verifies one transient lock error is retried and then stored.
`ParslAWSProviderCancel.tla` adds AWS EC2 cancellation: linger rejection, remote termination
failure, successful local cleanup, and the current stale-local-ID exception after a successful
remote terminate. Fixed configurations model idempotent local cleanup.
`ParslGoogleCloudCancel.tla` adds Google Compute Engine cancellation. The current provider reports
successful remote deletion without changing the local resource status; the fixed configuration
marks the resource terminal. `tests/test_googlecloud_cancel_runtime.py` drives both delete
success and API failure with a fake GCE client.
`ParslMonitoringClose.tla` models `DatabaseManager.close`: abnormal exit finalizes a started
workflow once, normal exit avoids duplicate finalization, and both paths switch to drain mode and
signal the manager thread to stop. `tests/test_monitoring_close_runtime.py` exercises both paths.
`ParslSlurmCancel.tla` adds Slurm `scancel` cancellation, including command failure, successful
local cancellation, and the current foreign/local-resource mismatch path. The fixed configuration
updates only known local resources.
`ParslMonitoringBatch.tla` models the batching boundary in `DatabaseManager._get_messages_in_batch`.
With a zero interval, the current implementation checks elapsed time before reading the queue and
can return an empty batch while an event is waiting; the fixed branch consumes the available event.
The runtime probe and TLC counterexample document this starvation edge case.
`ParslMonitoringBatchAtomicity.tla` models bulk STATUS insertion: a duplicate key rolls back the
whole SQLAlchemy batch, and the current `_insert` path drops valid sibling events. The runtime
SQLite probe and fixed branch make the valid-message preservation contract explicit.
`ParslMonitoringThreshold.tla` models the zero `batching_threshold` edge: the current batch loop
returns before reading an available event, while the fixed branch consumes one available message.
`ParslRetryHandler.tla` models the retry-budget contract when a user `retry_handler` returns a
failure cost. The current path accepts a zero cost, so `retries=0` can launch another physical
attempt; the runtime probe reproduces this, and the fixed branch charges at least one unit.
`ParslMemoFunctionIdentity.tla` models function-body changes across memoized calls. The current
`id_for_memo_function` key uses only module and name, so two different bodies collide; the runtime
probe creates same-identity functions with different results and observes the same hash.
`ParslExecuteWaitTimeout.tla` models scheduler-command timeout cleanup in `utils.execute_wait`.
The current path re-raises `TimeoutExpired` while leaving the subprocess alive; the runtime probe
uses a fake process to verify that no kill/terminate operation occurs.
`ParslMemoDictOrdering.tla` models dictionary-key normalization in `id_for_memo_dict`. The current
direct `sorted(dict)` call rejects valid heterogeneous Python keys; the runtime probe reproduces
the `TypeError`, while the fixed branch uses a canonical ordering.
`ParslRsyncQuoting.tla` models shell argument construction in `RSyncStaging` in-task wrappers.
The current string interpolation splits valid paths containing spaces; the runtime probe captures
the resulting command words, while the fixed branch quotes each argument.
`ParslCommandDeadline.tla` refines the HTEX command-client timeout boundary. If the deadline has
already elapsed, the current implementation passes a negative timeout to ZMQ `poll`; the runtime
probe records that argument, while the fixed branch clamps it to zero.
`ParslGridEngineDuplicateStatus.tla` models duplicate qstat records. The current `_status` path
removes a known job from `jobs_missing` twice and raises `ValueError`; the runtime probe reproduces
the duplicate-line failure, while the fixed branch ignores the second removal.
`ParslLSFDuplicateStatus.tla` models the corresponding LSF `bjobs` boundary. Because LSF uses a
set, duplicate records raise `KeyError` on the second removal in the current path; the runtime
probe and fixed idempotent branch make this scheduler-specific difference explicit.
`ParslSlurmDuplicateStatus.tla` models the same set-removal boundary in Slurm `_status`. Duplicate
status rows currently raise `KeyError`; a fixed idempotent bookkeeping branch is checked with the
real provider parser.
`ParslTorqueDuplicateStatus.tla` models the list-removal boundary in Torque `_status`. Duplicate
qstat rows currently raise `ValueError`; the runtime parser probe and fixed idempotent branch cover
the provider-specific path.
`ParslPBSProJobIdAlias.tla` models PBS Pro's JSON job-id normalization boundary. A short id and a
fully qualified id can both normalize to one local resource, causing a second list removal in the
current parser; the runtime probe and fixed idempotent branch cover this alias collision.
`ParslJoinListMutation.tla` models mutable aliasing of a `join_app` Future list between registration
and callback. The current DFK stores the caller's list directly, so clearing it before the callback
can make the outer result empty; the runtime probe exercises `handle_join_update` and the fixed
branch snapshots membership.
`ParslFTPConnectionCleanup.tla` models FTP in-task stage-in connection lifetime. A failed
`retrbinary` currently bypasses `ftp.quit()`; the runtime probe observes the open fake connection,
while the fixed branch closes it on failure.
`ParslHTTPPartialCleanup.tla` models HTTP streaming publication. A later `iter_content` failure
currently leaves earlier bytes at the destination path; the runtime probe observes the partial file,
while the fixed branch removes the incomplete publication.
`ParslDataFutureFalseyException.tla` models parent exception propagation through `DataFuture`.
The current truthiness check treats a custom falsey exception as success; the runtime probe uses a
real `Future` and `DataFuture`, while the fixed branch tests exception presence explicitly.
`ParslFileBytes.tla` adds bounded symbolic byte chunks, checksums, temporary buffers, corruption
repair, source-version changes during stage-in, and atomic stage-in/stage-out publication.
The minimal corrupted-output and input-stage-in configurations are now included in the recent
smoke sweep, so corruption repair and dependent-task blocking remain continuously checked.
`ParslStageOutFuture.tla` refines output stage-out into separate-task, in-task, and no-staging
paths, including stage-out failure/retry and dependent-task gating on the output `DataFuture`.
`ParslMultiOutputStageOut.tla` extends the output protocol to two independently completing files
sharing one application dependency. `tests/test_multi_output_stageout_runtime.py` exercises the
real `DataManager.stage_out()` calls and verifies both parent-Future bindings.
`ParslClock.tla` separates wall-clock ticks, heartbeat transport and expiry, attempt start/deadline
timestamps, retry selection after timeout or manager loss, and stale late-result delivery. A
zero-retry configuration checks the terminal timeout path explicitly; lost attempts can now retry
after manager recovery while their late results remain stale.
`ParslHeartbeatBoundary.tla` checks the strict HTEX expiration inequality, heartbeat reset ordering,
and conversion of a manager's in-flight tasks into failure reports at expiry.
`ParslHeartbeatClockJump.tla` separates adjustable wall-clock time from monotonic elapsed time.
`ParslHeartbeatClockRollback.tla` covers the opposite clock adjustment: a backward `time.time()`
jump can suppress heartbeat expiry in the current branch, while the fixed branch uses monotonic
elapsed time and preserves the expiry threshold.
The current `time.time()`-based expiry can remove a recently healthy manager after a forward clock
jump; `tests/test_heartbeat_clock_jump_runtime.py` reproduces the decision with the real method.
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
Its current, fixed, and non-duplicate configurations are now part of the recurring smoke sweep;
the SQLite bridge in `tests/test_monitoring_db_runtime.py` and status-history probe remain the
concrete runtime checks.
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
completes without callbacks. `ParslJoinValueList.cfg` adds the distinct non-empty all-value list
shape, which is also rejected before callback registration.
`ParslJoinNoneResult.tla` makes Python `None` an explicit successful inner result and checks exact
propagation through both single and list-valued joins. The accompanying runtime probe uses the
real thread executor rather than treating falsey results as missing values.
`ParslJoinRetry.tla` adds physical inner attempts and verifies that retryable inner failures remain
unresolved to the outer join until a final attempt succeeds or fails.
`ParslJoinCancellation.tla` models a cancelled inner Future. The current callback's
`future.exception()` raises `CancelledError` and leaves the outer task joining; the fixed
configuration maps cancellation into terminal join failure.
`ParslJoinListCancellation.tla` applies the cancellation boundary to a list-valued join. The
current list exception scan also escapes through `CancelledError`, while the fixed branch maps it
to terminal outer failure; `tests/test_join_list_cancellation_runtime.py` exercises the real path.
`ParslNestedJoin.tla` adds a nested join layer and checks that leaf completion/failure propagates
through the nested handle before the outer join can complete.
`ParslTaskTransport.tla` connects object-graph serialization to task/result transport, including
envelope corruption, decode rejection, dispatch gating, worker loss, retry correlation, and stale
result suppression.
`ParslDependencyTraversal.tla` models the real shallow/deep dependency-resolver boundary for a
direct Future and a Future nested in a container. Its shallow configuration intentionally exposes
the worker receiving a nested Future object, while the deep configuration proves recursive gather
and unwrap before execution.
`ParslDependencyTraversal.tla` now also checks deep traversal through dictionary values and keys,
matching the resolver's recursive dict implementation and runtime probes.
`ParslDependencyTraversal.tla` now includes tuple and set shapes as well; deep configurations
match the resolver's registered container handlers and the runtime probes.
`ParslHtexResultQueue.tla` probes the concrete HTEX result queue worker, including valid and
exception result decoding, malformed/duplicate messages, interchange failure, and Future orphaning
when the current pop-before-validation path exits the worker.
The companion `ParslHtexWorkerWatchdog` busy and idle configurations are now in the smoke sweep;
the busy path is exercised by `tests/test_htex_worker_watchdog_runtime.py` and emits a logical
WorkerLost result before replacement.
`ParslHtexResultDecodeFailure.tla` separates corrupt result-payload decoding from malformed fields:
the current `tasks.pop` before `deserialize(result)` can orphan a pending Future, while the fixed
branch reports a terminal deserialization failure; `tests/test_htex_result_decode_failure_runtime.py`
drives the real worker.
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
`ParslMPIBacklogRetry.tla` models the concrete `MPITaskScheduler._schedule_backlog_tasks` loop:
when a queued task still cannot fit, the current implementation requeues it and recursively calls
itself until Python raises `RecursionError`; the fixed branch stops the pass and retries after a
resource return. `tests/test_mpi_backlog_retry_runtime.py` reproduces the live recursion path.
`ParslMPINoResourceResult.tla` models the adjacent MPI result-path defect documented in the
source (`Issue #3427`): a successful task with no `num_nodes` allocation reaches an assertion
instead of returning its result. `tests/test_mpi_no_resource_result_runtime.py` reproduces the
current assertion using a task result with an empty node map; the fixed branch makes node release
conditional and still delivers the result.
The recurring sweep also executes `ParslClusterProviderUnknownJob.tla` and
`ParslLSFResourceValidation.tla`: the former checks that a stale scheduler ID is handled as an
explicit missing observation, while the latter rejects non-positive `cores_per_node` values before
deriving block capacity. Their concrete bridges are
`tests/test_cluster_provider_unknown_job_runtime.py` and
`tests/test_lsf_resource_validation_runtime.py`.
`ParslExecutorShutdown.tla` refines concrete shutdown behavior: ThreadPool waits for accepted
work, WorkQueue's collector fails tasks left behind during process shutdown, and HTEX closes its
interchange before in-flight cleanup. It also checks that shutdown rejects new submissions.
The model is now part of `scripts/tlc_recent_models.sh`; the real ThreadPool bridge
(`tests/test_thread_executor_runtime.py`) passes all three shutdown/resource-admission probes,
and bounded TLC simulation reaches 100,001 checked states for the invariant set.
The same sweep now includes `ParslTaskVineFactory.tla` (factory creation, configuration,
context exit, and construction failure) and `ParslPeriodicTimer.tla` (immediate callback,
callback-failure isolation, bounded periodic callbacks, and quiescent close).
It also includes the current/fixed `ParslTimeoutMonitoring` configurations, which connect
heartbeat expiry and task deadlines to late-result rejection and monitoring-status stability;
`tests/test_retry_timeout_runtime.py` provides the concrete timeout/retry bridge.
`ParslTimerReentrantClose` is now included as well, checking callback self-close behavior and
the fixed no-self-join path with `tests/test_timer_reentrant_close_runtime.py`.
`ParslWorkQueueResults.tla` refines WorkQueue's collector result protocol: valid result files,
deserialization failures, app exceptions, no-result reports, and final cleanup of outstanding
tasks when the collector exits.
`ParslWorkQueueShutdown.tla` is now in the recurring smoke sweep, with the real collector-finally
cleanup exercised by `tests/test_workqueue_shutdown_runtime.py`.
`ParslTaskVineShutdown.tla` now has the same recurring check for TaskVine manager-failure cleanup,
backed by `tests/test_taskvine_shutdown_runtime.py`.
`ParslWorkQueueDuplicateReport.tla` refines the same collector with a stale/duplicate report
interleaving. It captures the current `tasks.pop(task_report.id)` `KeyError` path, the resulting
collector exit and unrelated-future cleanup, and a candidate guard that ignores reports whose
Future was already removed.
`ParslCallableSerializerCache.tla` isolates callable-object dispatch through the cached Dill
serializer. It models the current failure for callable objects with `__hash__ = None` and a
candidate uncached path that still reaches `dill.dumps`.
`ParslFluxResult.tla` refines FluxExecutor's wrapped Future, result-file decoding, abnormal exit,
and cancellation propagation; its actual configuration preserves a cancellation-orphan probe and
the fixed configuration checks the candidate propagation fix.
`ParslFluxSubmissionFailure.tla` is now in the smoke sweep and checks that a submit-thread
exception drains every queued Future before Flux shutdown completes; the real bridge is
`tests/test_flux_submission_failure_runtime.py`.
`ParslTaskVineResults.tla` refines TaskVine's manager report and collector protocol, including
result-file failure mapping and cleanup of all outstanding Futures after manager failure.
It is now included in the recurring smoke sweep, with valid, missing, corrupt, exception, and
manager-exit cases exercised by `tests/test_taskvine_results_runtime.py`.
`ParslTaskVineDuplicateReport.tla` adds the stale-report interleaving to that collector. It
captures the current duplicate-ID `KeyError`, the resulting collector exit and unrelated-future
cleanup, and the candidate idempotent guard.
`ParslRadicalPilotResults.tla` refines RadicalPilot callback mapping for Bash/Python/MPI tasks,
master failure propagation, cancellation, and the shutdown pending-Future probe.
Its current/fixed configurations are now in the recurring smoke sweep, with callback coverage
provided by `tests/test_radical_results_runtime.py`.
`ParslGlobusComputeConfig.tla` refines Globus Compute's temporary per-submit resource and endpoint
configuration and records the caller-side serialization assumption needed to avoid cross-submit
interference for either field.
`ParslProviderKinds.tla` refines concrete provider behavior for Slurm-like and Kubernetes-like
backends: submit/status/cancel outcomes, backend-to-Parsl state translation, missing jobs,
unknown status, timeout distinction, cancellation failure, and CPU-per-task admission.
It is now included in the recurring TLC smoke sweep so the provider-kind contract is checked
alongside the provider poller and status-shape models.
The Work Queue executor models are now covered as well: result-file decode outcomes, collector
shutdown cleanup, cancelled or duplicate result races, resource-category admission, and submit
serialization/process failures with orphaned-Future rollback candidates. Runtime probes in
`tests/test_workqueue_*_runtime.py` exercise the corresponding current behavior.
`ParslAWSProviderStatus.tla` is also in the sweep, covering EC2 pending/running/terminated
translation, omitted instance responses, and the candidate completion mapping for a missing
requested instance; the AWS runtime probes cover status, submit, unknown-instance, and cancel
bookkeeping boundaries.
Azure provider coverage now includes short/unknown VM status views, local-resource bookkeeping,
partial VM provisioning rollback, linger-mode cancellation, and idempotent cleanup after a
successful delete whose local instance ID is already absent. The corresponding current/fixed
branches are in the TLC sweep and the runtime probes cover the concrete Azure methods.
Google Cloud provider coverage now includes region-to-zone selection, unknown GCE status
translation, failed-create instance numbering, and cancellation status synchronization. Current
and candidate-fixed branches are in the sweep, with runtime probes covering the concrete GCE
provider methods.
HTCondor coverage now includes chunk-size validation, malformed and failed `condor_q` output,
stale local job IDs, submit output parsing, and chunked cancellation. The current parser and
bookkeeping failures are retained as counterexample configurations beside the fixed candidates;
the Condor runtime probes exercise these concrete scheduler boundaries without requiring a live
HTCondor installation.
Grid Engine coverage now includes qstat malformed-record handling, malformed-record continuation
within a batch, duplicate status lines, qsub empty/failure/success output, and qdel handling for
known and unknown jobs. These models preserve the scheduler-specific terminal-state conventions
while making the parser and local-resource failure paths explicit.
LSF coverage now includes duplicate `bjobs` lines, missing-job completion semantics, unknown-job
cancel handling, non-positive `cores_per_node`, and bsub success/failure/malformed output. The
runtime probes cover the concrete LSF methods, while TLC keeps current behavior and candidate
fixed behavior side by side.
Slurm coverage now includes strict batching compatibility, duplicate and malformed status records,
foreign scheduler jobs, cancellation bookkeeping, and custom submit-regex output. The runtime
probes exercise `sbatch`, `sacct`, and `scancel` boundaries without a live scheduler.
PBS Pro coverage now includes malformed qstat JSON, foreign jobs, short/qualified job-ID alias
collisions, and empty versus valid qsub output. The current and candidate-fixed status/submit
contracts are in the TLC sweep, with runtime probes for the concrete JSON and scheduler paths.
Torque coverage now includes foreign and duplicate qstat records, stale output after command
failure, qdel terminal-state conventions, empty/valid qsub output, and non-positive
`tasks_per_node` admission. Current and fixed branches are included in the recurring sweep.
LocalProvider coverage now includes live-process exit-file races, marker precedence after cancel,
stale cancellation/status IDs, requested-status scoping, failed-launch script cleanup, and zero
`tasks_per_node` admission. These models connect local process/file semantics to provider status
and resource bookkeeping.
Kubernetes coverage now includes Pending-versus-Running admission, API cancellation responses,
stale cancellation/status IDs, read-error visibility, and submit-time resource state. The current
and fixed branches are in the recurring TLC sweep, with runtime probes using fake Kubernetes API
clients.
The remaining provider utility contracts are now also covered: duplicate provider job IDs,
duplicate poller registration, wall-clock rollback in provider polling, and sub-minute walltime
conversion. Each has a current counterexample and a fixed/valid TLC configuration; runtime probes
exercise the corresponding Python helpers.
The provider-free ThreadPoolExecutor abstraction is now covered: blocking and non-blocking
shutdown, pending versus running Future cancellation, resource-spec validation, and max-thread
count validation. Runtime probes exercise the real executor and Future behavior.
The command-execution boundary is now covered as well: malformed packed task messages are rejected
before invocation, callable values and exceptions cross the execution boundary, and timeout paths
explicitly distinguish process cleanup from merely re-raising an exception. Runtime probes cover
`execute_task`, `execute_wait`, and the Bash timeout helper.
`ParslPoolExecutorMap` is now in the sweep, checking eager submission, input-order result
iteration, iterator timeout, and late completion without implicit Future cancellation; the runtime
probe covers the same timeout/cancellation contract.
HTEX submit-side coverage now includes concurrent task-counter allocation, queue failure rollback,
and serialization-before-Future allocation ordering. Runtime probes reproduce the duplicate task ID
and orphaned pending Future behaviors, while fixed configurations check the cleanup candidates.
BlockProvider bad-state handling is now covered: marking an executor bad fails outstanding tasks,
records the cause, rejects later submissions, and must tolerate callbacks mutating or completing
the task dictionary during the failure sweep. Current mutation/order failures and fixed snapshot
paths are included in TLC, with runtime probes for each behavior.
CommandClient coverage now includes REQ/REP timeout poisoning, close/send races, lock acquisition
past a deadline, unused max-retry behavior, pre-send timeout reuse, and negative poll-timeout
calculation. Runtime probes exercise the corresponding ZMQ command-client paths.
Heartbeat coverage now includes strict expiry thresholds, in-flight task loss accounting, wall-clock
jumps versus monotonic age, stale late acknowledgements, and provider UNKNOWN versus terminal
states. Runtime probes cover manager expiry, heartbeat messages, and clock-jump behavior.
Monitoring coverage now includes atomic filesystem-radio publication, file-transfer version checks,
zero-interval batching, monotonic batch clocks, close idempotence, permanent and transient DB
errors, ordered event delivery, and zero-threshold queue handling. SQLite/runtime probes exercise
the corresponding DatabaseManager and radio paths.
FTP staging coverage now includes connection cleanup, partial destination cleanup, and in-task
stage-in artifact publication. Failed transfers remain counterexample branches, while fixed paths
remove partial bytes/close connections before exposing success or failure.
HTTP staging coverage now includes response cleanup, atomic replacement of existing destinations,
partial-stream cleanup, and non-2xx status validation before user-task execution. Runtime probes
cover streaming failures and separate/in-task stage-in paths.
Rsync staging coverage now includes shell-safe path quoting, stage-in gating before app execution,
stage-out failure after app completion, and successful transfer publication. Runtime probes cover
the command builder and both in-task/separate staging paths.
File-object coverage now includes clean-copy semantics (preserving URL metadata while clearing
site-local paths), local versus staged path resolution, and malformed zip URL rejection. Runtime
probes exercise the corresponding `File` and zip staging helpers.
Globus staging coverage now includes endpoint child-path validation, stage-in/stage-out Future
dependencies, atomic token-file publication, and serialized per-submit resource configuration.
Runtime probes cover endpoint/path and token-cache behavior, including the current race and
truncation counterexamples.
DataFuture coverage now includes cancellation propagation: a cancelled parent must not be treated
as successful file readiness. Runtime probes cover cancelled/failed parents, falsey exceptions,
clean file copies, and dependent-app gating.
The remaining staging contracts are now covered: multi-output stage-out gating, first-capable
provider dispatch, and zip archive stage-out retry/idempotence. Runtime probes cover output-wise
dependency gating, provider selection, archive bytes, and duplicate-entry behavior.
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
`ParslCondorStatusFailure.tla` refines that boundary with the `execute_wait` return code. The
current provider parses failed `condor_q` stdout anyway, so stale output can overwrite a running
resource or a truncated failure response can crash; fixed configurations preserve local state.
`tests/test_serialization_runtime.py` exercises the current serialization facade against real
closures, callable/data headers, three-part apply-message packing, and a deliberately failing
object graph. It complements the finite TLA+ serialization-wire models with runtime evidence.
It also checks closure snapshot timing and nested argument-object graph preservation.
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
`tests/test_monitoring_deferred_runtime.py` runs the real `DatabaseManager.start` loop against a
temporary SQLite database, proving that an early worker message is replayed after TASK_INFO/TRY
insertion and that a duplicate deferred message keeps only the latest observation.
`tests/test_datafuture_runtime.py` also checks the real `DataManager.optionally_stage_in` clean-copy
boundary: a staging operation receives a fresh `File` without the caller's site-local path, while
the original object and its parent `DataFuture` remain intact.
`tests/test_retry_timeout_runtime.py` distinguishes the standard-library caller wait timeout from
Parsl app walltime: a short `Future.result(timeout=...)` raises `TimeoutError` but the same real
thread task later succeeds, while walltime still produces `AppTimeout`.
`tests/test_serialization_runtime.py` includes a framing counterexample for the current
`unpack_buffers`: a declared length larger than the received bytes is silently sliced instead of
rejected. `ParslSerializationLengthFixed.cfg` records the strict parser behavior expected for a
future hardening change.
`tests/test_serialization_frame_count_runtime.py` records the complementary extra-frame behavior:
`unpack_and_deserialize` invokes the deserializer for a fourth buffer before its final count
assertion. `ParslSerializationFrameCount.tla` checks count validation before decode.
`ParslApplyMessageArity.tla` applies the same arity contract to the public
`unpack_apply_message` function, which currently returns extra decoded frames before
`execute_task` fails; its fixed branch rejects non-three-frame messages at unpack time.
`tests/test_join_runtime.py` runs the actual `join_app` callback protocol on a local thread
executor, covering single Futures, ordered duplicate references, empty lists, `JoinError`,
nested joins, scalar-return rejection, mixed-list rejection, and non-empty all-value list
rejection.
`tests/test_dependency_traversal_runtime.py` runs the real default shallow resolver and the real
`DEEP_DEPENDENCY_RESOLVER`, checking that a nested list Future is either unwrapped or reaches the
callable unchanged according to configuration.
`tests/test_join_callback_runtime.py` calls the real `DataFlowKernel.handle_join_update` with
controlled Futures, checking early-callback gating, ordered duplicate aggregation, duplicate
callback suppression, `JoinError` metadata, and the cancelled-inner callback escape modeled by
`ParslJoinCallbackRace.tla` and `ParslJoinCancellation.tla`.
`tests/test_join_runtime.py` also returns an already-completed `concurrent.futures.Future` from a
real `join_app`, checking the immediate `add_done_callback` registration path modeled by
`ParslJoinImmediateCallback.tla`.
`tests/test_retry_timeout_runtime.py` runs a retryable app and a walltime-limited app on the
real thread executor, confirming distinct physical attempts and terminal `AppTimeout` behavior.
`tests/test_timeout_timer_runtime.py` drives the real `timeout` wrapper directly, checking timer
cleanup after fast return and ordinary function exception, plus timeout injection for a slow call.
It also runs a real Python app that catches the injected `AppTimeout` and returns normally; this
current behavior is modeled by `ParslPythonTimeoutCatch.tla`, whose fixed configuration disallows
successful completion after timeout injection.
`tests/test_memoization_runtime.py` runs duplicate and distinct cached calls plus a dependent app,
checking the real BasicMemoizer result path and execution count.
`tests/test_lsf_status_runtime.py` drives the current LSF provider parser with deterministic
`bjobs` output, checking foreign-job filtering, unknown-state mapping, and missing-job fallback.
`tests/test_lsf_submit_runtime.py` drives the real LSF `bsub` parser with fake command results,
checking script/command construction, successful job registration, scheduler failure, and
successful-but-unparseable output.
`tests/test_lsf_cancel_runtime.py` drives the real LSF `bkill` path, checking successful and failed
cancellation plus the current unknown-job `KeyError` boundary.
`tests/test_kubernetes_polling_runtime.py` drives the current Kubernetes polling method with a
mock API client, reproducing the read-error identity-comparison path and checking normal terminal
pod translation.
`tests/test_kubernetes_submit_runtime.py` drives Kubernetes pod creation with a fake CoreV1 API,
checking successful resource registration and API error propagation. The current source's initial
`RUNNING` status is captured by `ParslKubernetesSubmit.tla`; the fixed model waits in `PENDING`.
The current/fixed submit configurations are now part of the recurring smoke sweep.
`tests/test_kubernetes_cancel_runtime.py` drives pod deletion with a fake API, distinguishing
exception propagation from a returned error object that the current wrapper ignores. The
`ParslKubernetesCancel.tla` fixed model preserves `RUNNING` for that returned-error case.
`tests/test_aws_status_runtime.py` drives `AWSProvider.status` with a fake EC2 client, checking
missing-instance behavior and normal instance-state translation.
`tests/test_aws_submit_runtime.py` drives `AWSProvider.submit` with a fake instance launcher,
checking successful registration, failed launch handling, unknown-state fallback, and the empty
launch-response unpacking path modeled by `ParslAWSProviderSubmit.tla`.
The narrower empty-response current/fixed model is also in the recurring smoke sweep, making the
response-validation boundary explicit.
`tests/test_pbspro_submit_runtime.py` executes the PBS Pro submit parser with temporary scripts
and deterministic `qsub` output, checking the empty-output and registered-job paths.
`tests/test_pbspro_status_runtime.py` drives PBS Pro's JSON status parser, checking known-job
translation, scheduler failure preservation, and the current foreign-job `KeyError` boundary.
`tests/test_pbspro_job_id_alias_runtime.py` drives the same parser with both `42` and
`42.server` JSON keys, reproducing the current duplicate `jobs_missing.remove` failure modeled by
`ParslPBSProJobIdAlias.tla`.
`tests/test_condor_status_failure_runtime.py` drives failed `condor_q` responses with valid and
truncated stdout, covering `ParslCondorStatusFailure.tla` without a Condor installation.
`tests/test_thread_executor_runtime.py` drives the real ThreadPoolExecutor shutdown and submit
admission paths, including accepted-work completion and resource-specification rejection.
`tests/test_future_cancellation_runtime.py` checks the concrete cancellation contract: AppFuture
and DataFuture cancellation raise `NotImplementedError`, while an underlying queued thread Future
can still be cancelled before it starts.
`tests/test_future_projection_runtime.py` drives real `AppFuture.__getitem__` and `__getattr__`
lifting, including deferred execution, source-failure propagation, invalid-key failure, and
non-blocking projection construction.
`tests/test_slurm_status_batch_runtime.py` drives Slurm's batched status method, checking scheduler
command failure preservation and successful reported/missing-job application.
`tests/test_slurm_submit_runtime.py` drives Slurm `sbatch` submission with deterministic output,
checking normal registration, empty-output rejection, and the custom-regex named-group failure.
`tests/test_mpi_spec_runtime.py` drives the real MPI resource-specification validator, checking
empty-spec rejection, positive-node rank derivation, and the zero-node division failure modeled by
`ParslMPISpec.tla`.
`tests/test_mpi_prefix_runtime.py` drives the real MPI prefix composer, checking host/rank prefix
construction for `mpiexec`, `srun`, and `aprun`, plus rejection of an unsupported launcher.
`tests/test_workqueue_results_runtime.py` drives the real WorkQueue collector method with fake
queues and serialized files, checking valid values, app exceptions, corrupt results, and cleanup
of outstanding Futures when the submit process exits.
`tests/test_workqueue_submit_runtime.py` drives the real WorkQueue submit method in a fake local
filesystem, reproducing orphaned `_tasks` Futures both when serialization fails and when the
submit process is already dead, while checking resource-key rejection before mapping.
`tests/test_flux_result_runtime.py` drives Flux's real result callback with serialized `TaskResult`
files and fake underlying futures, checking result decoding, failure mapping, and the cancellation
wrapper behavior modeled by `ParslFluxResult.tla`.
`tests/test_taskvine_results_runtime.py` drives TaskVine's real collector with manager reports and
serialized result files, checking valid/exception/corrupt/no-result mappings and manager-failure
cleanup modeled by `ParslTaskVineResults.tla`.
`tests/test_radical_results_runtime.py` drives RadicalPilot's real callback with fake RP constants
and task objects, checking Bash/Python completion, cancellation, failures, master failure, and the
invalid non-exception path modeled by `ParslRadicalPilotResults.tla`.
`tests/test_globus_compute_runtime.py` drives Globus Compute's real wrapper submit method with a
fake SDK executor, checking override restoration, exception cleanup, and the unsynchronized
concurrent-specification race modeled by `ParslGlobusComputeConfig.tla`.
`tests/test_condor_submit_runtime.py` drives Condor submission with temporary scripts and fake
`condor_submit` output, checking valid cluster registration, command failure, and malformed
successful-output indexing modeled by `ParslCondorSubmit.tla`.
`tests/test_condor_cancel_runtime.py` drives Condor's chunked `condor_rm` path, checking per-chunk
results and the guarded handling of job ids absent from the local resource map.
`tests/test_torque_cancel_runtime.py` drives Torque `qdel` success/failure handling, including the
current successful-cancel-to-`COMPLETED` (exiting) resource status convention.
`tests/test_torque_submit_runtime.py` drives Torque `qsub` output parsing, checking successful job
registration, empty output, scheduler failure, and last-line selection for multiple ids.
`tests/test_grid_engine_status_runtime.py` drives Grid Engine qstat parsing, checking malformed
line failure, normal state translation, foreign-job filtering, and missing-job fallback.
`tests/test_grid_engine_submit_runtime.py` drives Grid Engine qsub submission with temporary
scripts and deterministic output, checking empty-output and normal job registration.
`tests/test_grid_engine_cancel_runtime.py` drives Grid Engine qdel success/failure and reproduces
the current successful-cancel unknown-job `KeyError` boundary.
`tests/test_azure_status_runtime.py` drives Azure VM status with a fake compute client, checking
running translation, pending fallback, and cloud API error propagation.
`tests/test_googlecloud_status_runtime.py` drives Google Compute Engine status with a fake
discovery client, checking normal translation, API error propagation, and unknown-state handling.
`tests/test_googlecloud_submit_runtime.py` drives the real Google Cloud `create_instance` method
with a failing image lookup, exposing that `num_instances` is incremented before a VM exists;
`ParslGoogleCloudSubmit.tla` records the current counterexample and fixed bookkeeping contract.
`tests/test_rsync_staging_runtime.py` drives the real RSync in-task wrappers with a fake
`os.system`, checking that stage-in failure prevents the user function while stage-out failure
is reported only after the user function has run. This is modeled by `ParslRsyncStage.tla`.
`tests/test_http_staging_runtime.py` drives the real HTTP in-task wrapper with a fake 404
response, recording that the current code writes the error body and runs the user function
without checking HTTP status. It also drives the separate `_http_stage_in` function and records
the same non-success-body behavior. `ParslHTTPStage.tla` keeps this as an executable counterexample.
`tests/test_ftp_staging_runtime.py` drives the real FTP in-task wrapper with a fake connection
drop after a partial write, recording that the user function is skipped but the partial local
file remains. It also drives the separate `_ftp_stage_in` function and observes the same residual
file. `ParslFTPStage.tla` models the cleanup contract.
`tests/test_globus_staging_runtime.py` drives the real `GlobusStaging.stage_in` and `stage_out`
dispatch paths with fake staging apps, checking that parent and application Future objects are
passed through unchanged. `ParslGlobusStageDependency.tla` models the corresponding gates.
`tests/test_globus_transfer_failure_runtime.py` drives `Globus.transfer_file` with a fake SDK and
an empty terminal-failure event list, reproducing the current diagnostic-indexing exception
modeled by `ParslGlobusTransferFailure.tla`.
`tests/test_htex_result_queue_runtime.py` drives the real HTEX `_result_queue_worker` with a fake
incoming queue, reproducing both the malformed-message orphaned-Future path and duplicate-result
`KeyError` already modeled by `ParslHtexResultQueue.tla`.
`tests/test_htex_result_decode_failure_runtime.py` sends a corrupt serialized result and confirms
the separate post-pop decode-failure orphaning path.
`tests/test_htex_submit_runtime.py` drives the real `HighThroughputExecutor.submit_payload` with a
failing outgoing queue, showing that current send failure leaves a pending Future in `tasks`; this
is modeled by `ParslHtexSubmitFailure.tla`.
`ParslHtexSubmitLifecycle.tla` refines that probe with the preceding serialization gate: a
serialization error must occur before task/Future allocation, while queue failure occurs after
allocation and requires rollback in the fixed branch.
`tests/test_htex_manager_loss_runtime.py` connects the real interchange expiry report to the real
HTEX result worker, checking serialized `ManagerLost` propagation into the task Future.
`tests/test_htex_version_mismatch_runtime.py` drives the real interchange registration parser with
a fake ROUTER message, checking fatal `VersionMismatch` serialization, kill-event ordering, and
rejection from the ready-manager set.
`tests/test_azure_cancel_runtime.py` drives Azure VM cancellation with a fake async delete client,
checking linger refusal, failure rollback, and successful instance removal.
`tests/test_azure_submit_runtime.py` drives Azure VM submission with fake resource/network/compute
clients, checking successful registration and the partial-state disk-attach failure modeled by
`ParslAzureProviderSubmit.tla`.
`tests/test_local_provider_runtime.py` drives LocalProvider's real exit-file state inference,
covering liveness, completion, malformed exit codes, cancellation, and a real local submit/output
collection path, including non-zero application exit handling.
The same runtime probe now exercises cancellation of a real local process group and terminal
`CANCELLED` observation.
The probe also records the current late-zero-exit convention: a numeric `.ec` marker can win after
a cancellation request, yielding `COMPLETED`.
`ParslLocalProvider.tla` models this provider-specific `.ec`/PID boundary; its current
configuration finds the late-marker cancellation counterexample and its fixed configuration
prioritizes cancellation during polling.
Both configurations are now part of the recurring smoke sweep, backed by the real local-process
and exit-file checks in `tests/test_local_provider_runtime.py`.
`ParslLocalProviderStatusScope.tla` models the current `status(job_ids)` implementation's loop
over all resources. Its current configuration exposes an unrelated missing `.ec` file aborting a
valid query, while the fixed configuration limits observation to requested IDs.
Its current/fixed configurations are now included in the recurring smoke sweep, backed by
`tests/test_local_provider_status_scope_runtime.py`.
`ParslGridEngineStatus.tla` models the Grid Engine malformed-qstat boundary. Its current
configuration reproduces the short-line crash; fixed and valid-output configurations pass.
`ParslGoogleCloudStatus.tla` models direct GCE status-table lookup: the current unknown-status
configuration produces a depth-2 `KeyError`-style crash, while tolerant and known-status paths
pass.
The three GCE status configurations are now part of the recurring smoke sweep, backed by
`tests/test_googlecloud_status_runtime.py`.
`ParslTorqueCancel.tla` makes that convention explicit: the current configuration violates a
strict success-to-`CANCELLED` invariant, while the fixed and failed-cancel configurations pass.
`tests/test_datafuture_runtime.py` runs a producer/consumer local dataflow with a real File output,
checking binary content readiness and dependent-task gating.
`tests/test_datafuture_cancellation_runtime.py` drives the real `DataFuture.parent_callback`,
showing that a failed parent propagates failure while a cancelled parent is currently published as
available because cancellation is not checked.
It also wires a failed producer's output `DataFuture` into a consumer and checks `DependencyError`
propagation without consumer execution.
`tests/test_dependency_runtime.py` separately exercises ordinary Future value propagation and
failure blocking on the local executor.
It also covers Slurm suspended/requeued mappings (`HELD`/`PENDING`) and executor-driven
`SCALED_IN` terminal cleanup with terminal-state invariants.
`ParslProviderStatusBatch.tla` models bounded scheduler status batches, atomic application of
successful output, and preservation of the prior status map when a scheduler command fails or
times out; missing Slurm jobs follow the current `COMPLETED` fallback behavior.
`ParslClusterProviderUnknownJob.tla` adds the common `ClusterProvider.status` unknown-ID boundary:
the current local-resource lookup raises `KeyError`, while the fixed branch returns `MISSING`.
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
`ParslHeartbeatLateAck.tla` adds the in-flight heartbeat acknowledgement race: after manager
expiry, the fixed branch ignores an old acknowledgement instead of resurrecting the removed
manager record.
`ParslResultRace.tla` separates physical attempt result production from callback delivery and
checks retry selection, late success/failure races, stale callback suppression, and one-time
Future resolution.
`ParslJoinCallbackRace.tla` models the actual `join_app` callback gate: early callbacks return
without finalizing, the final callback checks all inner Futures under a lock, failures become
`JoinError` only after all selected Futures are done, and duplicate callbacks are harmless.
The callback-race and immediate-callback configurations are now part of the recurring TLC sweep;
`tests/test_join_callback_runtime.py` and `tests/test_join_runtime.py` exercise the same early,
duplicate, failure, cancellation, and already-completed Future paths against the real kernel.
`ParslJoinReturnEquality.tla` is now in the sweep as well: it checks that return-shape validation
does not invoke user-defined equality before determining whether a join result is a Future or a
list. `tests/test_join_return_equality_runtime.py` reproduces the current callback escape and
pending outer Future.
The sweep also includes `ParslJoinFailureAggregation.tla` and `ParslJoinErrorRootCause.tla`.
Together they check that all failed inner Futures are collected in join-list order and that a
nested `JoinError` preserves the first leaf exception and representative path annotation. The
runtime bridges are `tests/test_join_failure_aggregation_runtime.py` and
`tests/test_join_error_root_cause_runtime.py`.
`ParslTaskStatusFutureOrdering.tla` is also in the sweep: it checks the concrete ordering in
`_complete_task_result`, where the logical task reaches `exec_done` before the public AppFuture is
resolved. `tests/test_task_status_future_ordering_runtime.py` records the status observed by the
Future completion callback.
The monitoring sweep also includes `ParslMonitoringMalformedWorkerMessage.tla`: malformed worker
task envelopes with neither `first_msg` nor `last_msg` must be discarded without killing the
database worker. `tests/test_monitoring_malformed_worker_message_runtime.py` reproduces the
current thread failure against the real `DatabaseManager`.
`ParslMonitoringCloseIdempotence.tla` now covers repeated abnormal shutdown: the first close
publishes the workflow finalization, while later closes must be no-ops. The runtime bridge
`tests/test_monitoring_close_idempotence_runtime.py` reproduces the duplicate update in the
current implementation.
`ParslMonitoringShutdownRace.tla` now covers the late-producer shutdown boundary: a migration
worker must not stop on an empty queue until its producer is closed, otherwise a message enqueued
immediately after the observation is stranded. `tests/test_monitoring_shutdown_race_runtime.py`
reproduces the current empty-queue race.
`ParslMonitoringShutdownDrain.tla` complements that race model with the normal shutdown path:
messages accepted before the kill signal are conserved across external-queue migration and
internal processing. `tests/test_monitoring_shutdown_drain_runtime.py` exercises the real queue
drain after the kill event.
`ParslMonitoringDeferredMultiplicity.tla` now covers multiple worker `first_msg` observations
arriving before the TRY row: the fixed branch preserves both deferred observations for replay,
while the current single-slot map overwrites the earlier one. The concrete bridge is
`tests/test_monitoring_deferred_multiplicity_runtime.py`.
The baseline `ParslMonitoringDeferred.tla` is also in the recurring sweep, checking the normal
first-message deferral/replay path, foreign-key gating, and latest-observation replacement. The
runtime bridge is `tests/test_monitoring_deferred_runtime.py`.
`ParslMonitoringDispatchEnvelope.tla` now covers the queue-envelope boundary before internal
dispatch: malformed tuples must be rejected without terminating the migration thread, while valid
two-element envelopes are admitted. `tests/test_monitoring_dispatch_envelope_runtime.py`
reproduces the current assertion on a one-element tuple.
`ParslMonitoringHubClose.tla` covers the public MonitoringHub cleanup lifecycle and idempotence:
the DB stop signal, process join, queue close, and queue join each occur once, even if `close()`
is called repeatedly. `tests/test_monitoring_hub_close_runtime.py` checks the real cleanup ordering
with deterministic doubles.
`ParslWorkerContactTimeout.tla` is now in the clock sweep, modeling the concrete HTEX worker
contact loop: heartbeats follow their period, contact refreshes the deadline, and the worker stops
at the threshold only after a no-message poll. The related real worker clock probes remain in
`tests/test_worker_contact_clock_rollback_runtime.py` and
`tests/test_worker_pool_heartbeat_runtime.py`.
`ParslTimedHeartbeat.tla` is now in the recurring sweep, combining manager heartbeat expiry,
per-attempt deadlines, and late-result handling; the current branch accepts a stale result while
the fixed branch classifies it without resolving the rejected Future. The concrete heartbeat
encoding probes remain in `tests/test_worker_pool_heartbeat_runtime.py`.
`ParslWorkerContactClockRollback.tla` is also in the sweep as a concrete clock-failure model:
the current wall-clock comparison can suppress expiry after a backward step, while the fixed
branch uses monotonic elapsed age. `tests/test_worker_contact_clock_rollback_runtime.py`
reproduces the wall-clock behavior with a deterministic time sequence.
`ParslHtexUnknownManagerMessage.tla` is now in the executor sweep for both unknown heartbeat and
unknown result messages. The model requires non-registration traffic from an unknown manager to
be ignored without creating a ready-manager record, replying, or forwarding a result;
`tests/test_htex_unknown_manager_runtime.py` drives the real interchange handler.
`ParslHtexUnknownTaskResult.tla` now covers stale result frames whose task IDs were removed by
retry, cancellation, or teardown: the current result worker dies on an unconditional lookup,
while the fixed branch discards the stale frame and continues to a live task. The runtime bridge
is `tests/test_htex_unknown_task_result_runtime.py`.
The recurring sweep also includes `ParslHtexManagerMessage.tla` for malformed multipart/pickle
messages and valid heartbeat messages: malformed input is ignored without state changes, while a
heartbeat updates contact time and emits the expected reply. The runtime bridge is
`tests/test_htex_manager_message_runtime.py`.
`ParslProviderStatusBatch.tla` is now in the provider sweep, checking bounded batch size,
failure atomicity, missing-job completion mapping, and terminal-state stability for scheduler
polls. `tests/test_provider_status_shape_runtime.py` provides the concrete provider status-shape
bridge.
`ParslProviderPolling.tla` is now in the provider sweep, covering submit admission, pending/running
status transitions, unknown-status failure, transient API errors, cancellation rollback, and
bounded polling. The clock/runtime probes in `tests/test_provider_poll_clock_runtime.py` and
`tests/test_provider_poll_clock_rollback_runtime.py` exercise the concrete polling boundary.
`ParslProviderStatusShape.tla` is now in the provider/executor sweep: a short `status()` response
must not abort the whole poll; the fixed branch preserves the known result and marks the missing
observation explicitly. `tests/test_provider_status_shape_runtime.py` reproduces the current
`IndexError` path.
`ParslPollerBadState.tla` is now in the provider sweep, checking failure-threshold handling,
outstanding-task failure, bad-state admission blocking, and the no-scale-after-bad-state rule.
`ParslDataManagerStageInOrdering.tla` is now in the staging sweep: the current ordering starts a
stage-in transfer before wrapper preparation, so wrapper failure can leave an orphaned transfer;
the fixed branch prepares the wrapper first and only then starts stage-in. This complements the
runtime staging-provider dispatch probes.
`ParslDataManagerStageOutOrdering.tla` mirrors the output side: wrapper construction must precede
starting a provider stage-out Future, otherwise wrapper failure leaves a live orphan transfer.
`tests/test_data_manager_stage_out_ordering_runtime.py` reproduces that current behavior.
`ParslSerializationEnvelopeMalformed.tla` is now in the serialization sweep: truncated or
headerless envelopes must become a controlled decode rejection rather than a raw framing error.
`tests/test_serialization_envelope_malformed_runtime.py` reproduces the current failure on a
truncated payload.
`ParslSerializationBinaryPayload.tla` is now in the serialization sweep, checking length-prefixed
framing for newline, NUL, and non-ASCII bytes. `tests/test_serialization_binary_payload_runtime.py`
round-trips the same byte classes through the real `pack_buffers`/`unpack_buffers` implementation.
`ParslSerializationFrameCount.tla` is also in the sweep: apply-message frame count is validated
before deserialization in the fixed branch, preventing extra frames from being decoded before
rejection. `tests/test_serialization_frame_count_runtime.py` reproduces the current four-frame
decode-before-assertion path.
`ParslSerializationShortFrameCount.tla` complements the extra-frame model for truncated
two-frame messages: the fixed branch validates the count before decoding, while the current
branch deserializes available frames first. `tests/test_serialization_short_frame_count_runtime.py`
reproduces that current path.
`ParslSerializationNegativeLength.tla` is now in the sweep, requiring a receiver to reject
negative length declarations before Python slicing. `tests/test_serialization_negative_length_runtime.py`
reproduces the current partial-slice then parse failure.
`ParslSerializationTruncatedLength.tla` adds declared-length validation: a frame claiming more
bytes than remain must be rejected before deserialization. `tests/test_serialization_truncated_length_runtime.py`
reproduces the current short-payload handoff.
`ParslSerializationLength.tla` is also in the sweep as the compact declared-vs-actual frame
length abstraction; the strict configuration rejects mismatches before exposing payload bytes.
`tests/test_serialization_runtime.py` exercises the concrete short-frame behavior.
`ParslSerializationSnapshot.tla` is also in the sweep, checking that callable/object content is
captured at `pack_apply_message` time and remains isolated from later source mutation. The real
snapshot bridges are `tests/test_function_object_contents_runtime.py`,
`tests/test_callable_argument_alias_runtime.py`, and `tests/test_callable_retry_transport_runtime.py`.
`ParslSerializationZMQBridge.tla` is now in the sweep, connecting serializer framing to ZMQ
transport, route validation, duplicate suppression, retry-attempt correlation, and stale-result
classification. Concrete bridges include `tests/test_zmq_serialization_runtime.py`,
`tests/test_callable_retry_transport_runtime.py`, and `tests/test_task_transport_runtime.py`.
`ParslCurveZMQCertificateMode.tla` is now in the ZMQ sweep, checking that secret keys load only
from private certificate directories and that missing keys or unsafe modes are rejected.
`tests/test_curvezmq_certificate_runtime.py` drives the real certificate loader.
`ParslWorkerPoolControlFrame.tla` is now in the serialization/HTEX sweep: valid heartbeat and
drain frames decode as distinct control records, while malformed pickle frames are discarded in
the fixed branch instead of crashing the receive loop. The runtime bridge is
`tests/test_worker_pool_control_frame_runtime.py`.
`ParslHtexResultDecodeFailure.tla` is now in the executor sweep: corrupt result payloads must not
orphan a pending Future after task-map removal. The fixed branch delivers a terminal decode error
and keeps the result worker alive; `tests/test_htex_result_decode_failure_runtime.py` reproduces
the current orphaning path.
`ParslHtexAmbiguousResult.tla` is now in the executor sweep: result frames carrying conflicting
success and exception fields are rejected as malformed in the fixed branch instead of silently
resolving the Future as success. `tests/test_htex_ambiguous_result_runtime.py` exercises the
real result handler.
`ParslHtexCancelledResult.tla` also covers a late result racing with user cancellation: the
current branch lets `set_result` raise and kills the result worker, while the fixed branch
discards the cancelled task's result and continues to later messages. The concrete bridge is
`tests/test_htex_cancelled_result_runtime.py`.
`ParslHtexDuplicateResult.tla` is now in the executor sweep: after the first result removes the
task map entry, a duplicate frame must be classified as stale and leave the result worker alive.
The related concrete result-queue probes cover duplicate/late frame handling.
`ParslSerializationPluginCache.tla` is now in the serialization sweep, checking dynamic plugin
loading exactly once and stable reuse for a second payload. The concrete bridge is
`tests/test_serialization_plugin_cache_runtime.py`.
`ParslSerializationPluginFailureCache.tla` is now in the sweep: a plugin that raises during
decode must not remain cached as if it were healthy. `tests/test_serialization_plugin_failure_cache_runtime.py`
reproduces the current poisoned-cache behavior.
`ParslSerializationPluginError.tla` is now in the sweep, covering an importable class that lacks
the serializer `deserialize` interface. `tests/test_serialization_plugin_error_runtime.py`
reproduces the current raw `AttributeError` and contrasts it with the already-wrapped import
failure path.
`ParslSerializationFallback.tla` is now in the sweep for primary success, primary failure with
secondary success, and all-serializer failure. `tests/test_serialization_fallback_runtime.py`
checks fallback ordering and re-raising of the final serializer exception.
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
`ParslSerializationPluginError.tla` models dynamic serializer headers: an importable class without
`deserialize()` currently leaks an attribute error, while the fixed branch wraps that plugin
interface failure.
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

`ParslMonitoringTaskRetry.tla` connects monitoring records to logical task retry and terminal
state: the current branch lets an old attempt event lower the database version after a newer
event, while the fixed branch preserves the database high-water mark and terminal consistency.

`ParslCallableClosureMemo.tla` connects closure contents to memoization: real serialized
closures differ when their captured values differ, while the current name/module-only key
collides and can return the first closure's result.
`ParslCallableMutationCache.tla` now also runs in the smoke sweep, checking that mutable callable
state cannot be hidden by a stale Dill serializer payload; `tests/test_callable_mutation_cache_runtime.py`
demonstrates the current cached-payload behavior.

The monitoring TRY-row bookkeeping model is now included in the recurring TLC smoke sweep:
the current configuration produces the failed-insert counterexample, while the fixed
configuration verifies that an unsuccessful insert does not poison the retry classification.

The `TasksOutgoing` close/put lifecycle is also in the smoke sweep. Its current branch reaches
the terminated DEALER socket after close, while the fixed branch rejects post-close submission
before touching the transport.

`ParslTaskTransportCloseRace.tla` now connects that sender lifecycle to the serialized task
boundary: incomplete or corrupt payloads cannot enter transport, and a closed sender cannot
publish a ready task. The runtime bridge packs a real callable with `pack_apply_message`, sends
one task, then reproduces the current post-close send failure.

The bounded file-content model `ParslFileBytes` is now also part of the recurring smoke sweep. It
checks per-chunk checksums, temporary-buffer isolation, source-version staleness, and atomic
stage-in/stage-out publication; the runtime Zip probe verifies the same bytes and checksums.

The combined `ParslClock` model is now in the smoke sweep as well. Its two configurations cover
heartbeat delivery/expiry, task deadlines, retry after timeout or manager loss, recovery, and
stale late results, including the zero-retry terminal timeout case.

The core `ParslMonitoringDB` model is now in the smoke sweep. It checks versioned asynchronous
radio events, bounded queueing and reordering, database write failure/retry, stale-event
suppression, and terminal-record stability; the SQLite runtime probe covers duplicate STATUS keys
and transient operational-error retry.

The provider/executor baseline is now in the smoke sweep too. `ParslExecutorProvider` covers
block allocation, manager registration, worker readiness, submission admission, provider failure,
drain/recovery, and scale-in; `ParslProviderExecutorBridge` checks provider terminal observations
revoke executor capacity and account for queued/running work. The lifecycle model retains a
deliberately broken scale-in-floor configuration alongside its fixed configuration.

The integrated join models are now in the smoke sweep: `ParslJoinFull` covers single/list/empty/
invalid returns, duplicate list positions, retry, cancellation, failure aggregation, and terminal
join handles; `ParslJoinEndToEnd` adds the logical-Future/physical-attempt split and ordered result
reconstruction for a retryable duplicate-preserving list.

The callable and wire-serialization boundary models are now in the smoke sweep. `ParslApplyMessageArity`
checks that the apply-message unpacker cannot expose an unexpected frame count; `ParslCallableArgumentAlias`
checks alias preservation across callable/argument decoding; and `ParslCallableDeserializeCache` checks
that a mutable callable is not returned from a stale deserialization cache. `ParslCallableSerializerCache`
and `ParslPoolExecutorCallableCache` cover unhashable callable admission, while `ParslSerializationEmptyRegistry`
and `ParslSerializerRegistry` cover explicit empty-registry failure and ambiguous plugin identifiers.
`ParslTaskTransport` and `ParslZMQ` connect object-graph serializability, framed task/result transport,
retry identity, duplicate delivery, route validation, and stale-result rejection. Runtime probes cover
the corresponding Parsl serializer, pool-executor, ZMQ, and task-transport paths.

The first explicit clock/timeout parameter models are now in the smoke sweep. `ParslHeartbeatParameterValidation`
checks admission of positive HTEX heartbeat period and threshold values; `ParslPythonTimeoutParameter`
checks that non-positive Python-app timeout delays are rejected instead of causing an immediate timer
fire; `ParslResourceMonitorClock` contrasts wall-clock scheduling with elapsed monotonic time after a
clock rollback; `ParslTimeoutTimer` checks cancellation on both normal return and ordinary exceptions;
and `ParslTimerIntervalValidation` checks negative periodic intervals. Runtime probes cover all five
boundaries, and the current configurations intentionally produce TLC counterexamples for the unsafe
branches while fixed and valid configurations pass simulation.

The Future/DataFuture foundation is also in the sweep. `ParslDataFutureCopy` models clean stage-in
copy isolation and dependency gating; `ParslDataFutureFalseyException` captures failure propagation
when a user exception has false boolean value; `ParslFutureCancellation` distinguishes public
AppFuture/DataFuture cancellation from cancellation of an underlying concurrent-futures object;
`ParslFutureProjection` models deferred `__getitem__`/`__getattr__` tasks and invalid-key/failure
propagation; and `ParslFutureWaitTimeout` separates caller-side `Future.result(timeout=...)` from
the app's own wall timeout. Runtime probes cover DataFuture staging, cancellation, falsey exceptions,
and deferred projections. The falsey-exception current branch produces a TLC counterexample; fixed,
normal, and other contract configurations pass simulation.

The next `join_app` refinement is in the sweep. `ParslJoinDuplicates` preserves duplicate Future
references as separate list positions and counts repeated failures; `ParslJoinMixedList` and
`ParslJoinReturnShape` validate accepted Future/list/empty-list returns before registering callbacks;
`ParslJoinNoneResult` treats `None` as a successful value; `ParslJoinRetry` separates logical inner
Futures from physical retry attempts; and `ParslJoinRetryCancellation` plus
`ParslJoinSingleCancellation` cover cancellation during retry and single-Future callbacks.
Runtime probes cover duplicate-preserving retries, `None` results, return-shape validation, and
cancellation. The current cancellation branches produce TLC counterexamples, while fixed branches
and the other valid shapes pass simulation.

Memoization now has a focused object-content sweep. `ParslMemoDictOrdering` models heterogeneous
Python dictionary keys that cannot be sorted during hashing; `ParslMemoIgnoreKey` validates unknown
`ignore_for_cache` names; `ParslMemoIgnoreOutputs` makes removal of the special `outputs` key
idempotent; `ParslMemoCheckpointOrder` checks that duplicate hashes select the newest checkpoint
rather than lexical directory order; and `ParslMemoExceptionCheckpoint` contrasts in-memory failed
Future reuse with failure persistence across restart. Runtime probes reproduce all five current
behaviors. Each current configuration produces its expected TLC counterexample, while fixed and
homogeneous/valid configurations pass simulation.

The callable/object-content layer now also covers caller-owned list mutation. `ParslInputListMutation`
models staging rewrites of an `inputs` list, and `ParslOutputListMutation` models clean-copy rewrites
of an `outputs` list. Both current branches mutate the caller-visible value, while snapshot/fixed
branches preserve it. The two runtime probes reproduce the current behavior and both fixed models
pass TLC simulation.

The executor/strategy baseline is now extended with `ParslExecutorKinds`, which distinguishes
provider-free local executors from manager/provider-backed HTEX, MPI, and Work Queue paths and checks
admission, drain, failure cleanup, and resource-request restrictions. `ParslNegativeScaleIn` models
negative `scale_in` slicing, while `ParslStrategy` and `ParslStrategyBlockCapacity` cover idle scale-in,
overload scale-out, minimum-block bounds, and zero-capacity validation. Runtime probes cover strategy
polling and negative scale-in. The current negative-input and zero-capacity branches produce TLC
counterexamples; fixed and normal configurations pass simulation.

The provider baseline now includes the remaining un-swept AWS cancel paths and the full local
provider state machine. `ParslAWSProviderCancel` covers successful remote termination, stale local
instance cleanup, and the linger path. `ParslLocalProvider` models process liveness, `.ec` exit
markers, malformed output, cancellation, and the late-success race; its current configuration
produces the expected strict-cancellation counterexample. Runtime probes cover real local process
launch/status/cancel behavior and failed-launch cleanup, while the AWS configurations pass TLC
simulation.

The Flux executor boundary is now represented by four focused models. `ParslFluxCancelSubmitRace`
covers cancellation before the underlying Flux future is bound; `ParslFluxCancelUnderlyingState`
propagates an already-cancelled underlying future; `ParslFluxProviderStatusEmpty` handles an empty
provider status response; and `ParslFluxResult` covers result-file validity, nonzero/task exceptions,
shutdown, and cancellation propagation to the Parsl-facing wrapper. Runtime probes cover ten Flux
paths. All four current configurations produce the expected cancellation/status counterexamples,
while fixed configurations pass TLC simulation.

The HTEX protocol layer now includes address-probe timeout propagation, `cores_per_worker` admission,
priority/capacity dispatch, version-mismatch fatal handling, and ingress type validation for task IDs
and task context. `ParslHtexDispatchPriority` passes the normal priority and drain invariants;
the other current branches reproduce dropped zero timeouts, division by zero, post-mismatch admission,
and malformed-envelope crashes. Runtime probes cover all five concrete HTEX boundaries, and fixed or
valid configurations pass TLC simulation.

The HTEX manager/worker lifecycle is now extended with `ParslHtexManagerLoss`, which checks that
manager expiry emits a synthetic result that resolves the affected Future; `ParslHtexManagerTaskAdmission`,
which models registration, heartbeat expiry, retry, and stale-result correlation; and two worker
receiver models for malformed batch shapes and corrupt pickle frames. `ParslHtexMonitoringMessage`
covers optional monitoring payloads when no radio is configured. Runtime probes cover manager loss,
monitoring-disabled messages, malformed batches, and frame continuation. The current manager-loss,
worker receiver, and monitoring-disabled branches produce TLC counterexamples; fixed and enabled
configurations pass simulation.

Provider/executor resource-provisioning boundaries are now in the sweep. `ParslProbeAddresses`
covers empty candidate sets, successful probe replies, and timeout failure; `ParslProvisioningAdmissionMonitoring`
connects block allocation to task admission and failure monitoring; `ParslScaleInCancelShape` handles
short cancellation responses; `ParslScaleInRetryMonitoring` separates lost-task retry from late
results; and `ParslScaleOutFailureMonitoring` requires failed blocks to remain visible in monitoring.
Runtime probes cover five concrete paths. Current configurations reproduce missing monitoring,
shape-assertion, and late-result counterexamples; fixed/normal configurations pass TLC simulation.

The MPI executor baseline is now in the sweep. `ParslMPINonDivisibleRanks` models rank-per-node
derivation and rejects fractional allocations in the fixed branch; `ParslMPIPrefix` validates
launcher prefix selection; and `ParslMPISpec` checks legal resource keys, missing-rank derivation,
and zero-node validation. Runtime probes cover seven MPI construction/command paths. The current
non-divisible and zero-node configurations produce counterexamples, while fixed, valid, and prefix
configurations pass TLC simulation.

The compact end-to-end protocol `ParslEndToEnd` is now explicitly in the recurring sweep. It joins
dependency release, physical attempts, wire progress, worker execution, retry, timeout, and late
result correlation in one small state machine. The current configuration reproduces an old timed-out
attempt resolving the Future; the fixed configuration rejects it as stale. The corresponding runtime
probe passes, and the fixed TLC configuration passes simulation.

The remaining submit configuration aliases are now covered explicitly: `ParslHtexSubmitSuccess`
checks the successful task/Future mapping, while the Work Queue serialization-failure current and
fixed configurations exercise the same rollback contract with their concrete repository paths.
These cases pass or reproduce the expected counterexample under TLC; the existing submit runtime
probes cover the corresponding Python paths.

The monitoring database reorder configuration is now explicitly included in the sweep using the
versioned `ParslMonitoringDB` abstraction. I also added the separate `ParslDataFutureCancellation`
model: a cancelled parent currently publishes its DataFuture as available, while the fixed branch
propagates terminal failure. The existing DataFuture cancellation runtime probe covers this path;
current TLC produces the expected counterexample and the fixed configuration passes.

The dependency and join input layer is now expanded. `ParslDependencyTraversal` covers direct,
list, tuple, set, and dictionary Future locations under shallow versus deep traversal; shallow list
and dict configurations reproduce nested-Future leakage, while all deep shapes pass. The join sweep
also includes `ParslJoinValueList` (rejecting non-Future values) and `ParslJoinInternalExecutor`
(ensuring the outer join task targets `_parsl_internal`). Runtime probes cover twelve dependency/join
paths, including internal-executor selection and nested container unwrapping.

Retry-handler validation is now in the sweep. `ParslRetryHandler` covers zero-cost handlers bypassing
a zero retry budget; `ParslRetryHandlerNegativeCost` covers negative costs that make attempts
unbounded; and `ParslRetryHandlerNonNumericCost` covers invalid handler return types leaving a Future
pending. Runtime probes reproduce all three current behaviors. Current configurations produce TLC
counterexamples, while fixed and positive-cost configurations pass simulation.

The remaining join/dataflow edge cases are now in the sweep. `ParslJoinCancellation` and
`ParslJoinListCancellation` cover cancelled inner Futures; `ParslJoinMemoData` combines memo hits,
DataFuture readiness, and ordered callbacks; `ParslJoinRetryDuplicates` preserves duplicate list
positions across physical retries; `ParslLastCheckpointUUID` covers UUID-named run directories; and
`ParslResultRace` models failure/retry versus late success callbacks. Runtime probes cover nine join,
checkpoint, and memoization paths. Current cancellation/order/checkpoint configurations produce TLC
counterexamples; fixed, success, memo, and result-race configurations pass simulation.

The core lifecycle layer is now extended with `ParslDataFlowCleanup` (ordered, idempotent shutdown),
`ParslDataFlowWaitSnapshot` (late task insertion during `wait_for_current_tasks`),
`ParslResultDecodeRetry` (decode failure, retry, and stale result correlation), and
`ParslTaskStagingMonitoring` (complete stage-out before DataFuture readiness, consumer admission, and
monitoring persistence). Runtime probes cover cleanup and wait-snapshot behavior. Current wait,
decode, and staging/monitoring branches produce TLC counterexamples; fixed configurations pass.

The abstract wire/file configurations are now explicitly tracked as well. `ParslFileContent` checks
content tokens, chunk completion, and file publication; `ParslNestedSerialization` checks bounded
object-graph closure; `ParslResultSerializationFailure` checks an unencodable worker result; and
`ParslMessaging` checks bounded task/result queues, correlation, and serialization gates. These four
configurations pass TLC simulation under the shared `ParslAbstract` state machine.

The Work Queue/TaskVine result layer is now covered by `ParslWorkQueueSubmit`, which checks task-map
rollback after serialization or submit-process failure, and `ParslTaskVineCancelledResult`, which
ensures a cancelled report does not terminate the collector or fail unrelated later tasks. Runtime
probes cover sixteen Work Queue/TaskVine submission and result paths, including valid, malformed,
exception, and cancelled reports. Current failure branches produce TLC counterexamples; rollback and
fixed collector configurations pass simulation.

Two additional HTEX lifecycle models are now in the sweep. `ParslHtexForceScaleIn` makes the
busy-block behavior explicit: the current forced scale-in cancels an active worker context, while
the fixed branch protects it. `ParslHtexMonitoringBatchContinuation` checks that an optional
monitoring frame cannot abort a following valid task result when monitoring is disabled. Runtime
probes cover both paths; current configurations produce TLC counterexamples and fixed configurations
pass simulation.

Scheduler output parsing is now covered by `ParslJobStatusOutputReadError`, which aligns stdout and
summary read-error handling, and `ParslJobStatusOutputSummary`, which distinguishes missing files,
exact-threshold output, and head/tail truncation above the threshold. Runtime probes cover five
filesystem/status paths. The current summary-read error branch produces a TLC counterexample; fixed
and all summary-shape configurations pass simulation.

Callback-based executors are now covered by `ParslRadicalPilotFailurePayload`, which wraps a missing
exception payload before resolving a failed Future; `ParslRadicalPilotLateCallback`, which suppresses
DONE after cancellation; and `ParslRadicalPilotUnknownCallback`, which ignores callbacks for removed
tasks. `ParslGlobusComputeResult` models direct propagation of SDK success, failure, and cancellation
without an extra wrapper state. Runtime probes cover ten Radical Pilot/Globus Compute paths. Current
Radical Pilot configurations produce the expected callback/failure counterexamples; fixed and direct
SDK propagation configurations pass TLC simulation.

The executor transport lifecycle now includes `ParslResultsIncoming` for multipart receive, poll
timeout, and close behavior, `ParslResultsIncomingCloseRace` for get-after-close, and
`ParslTasksOutgoing`/`ParslTasksOutgoingCloseRace` for send and post-close put behavior. Runtime
probes cover seven real ZMQ pipe paths. Current close-race configurations reproduce socket-use-after-
close failures; normal, timeout, and fixed configurations pass TLC simulation.

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
The runtime baseline is reproducible with `python -m unittest discover -s tests -p
'test_*runtime.py'`; the current suite has 485 passing tests and intentionally uses local/fake
providers instead of external scheduler or cloud credentials.

The model is intentionally a bounded protocol abstraction. A passing TLC run means that the
specified finite abstraction satisfies the listed properties; it does not prove that every
implementation detail of Parsl is correct.
