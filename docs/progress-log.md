# Project Progress Log

This file is the durable project record for the TLA+ Parsl abstraction effort. Chat retention is
external to this repository, so important decisions, coverage counts, and the next audit target
are recorded here in English and committed with the model changes.

## 2026-09-30

### Current repository state

- Latest locally preserved commit: `d1d1d97` (`Compose retry result and monitoring persistence`).
- Foundational smoke inventory: 629 TLC cases and 427 Python runtime probes.
- The smoke inventory has been expanded across core dataflow, Futures, retries, stale results,
  ZMQ/serialization, callable snapshots, file bytes and staging, clocks/heartbeats/timeouts,
  monitoring persistence, executors, providers, schedulers, scaling, memoization, and `join_app`.
- The bug ledger records source/runtime findings separately from candidate fixed semantics. Current
  and fixed configurations are intentionally kept where a TLC counterexample documents the source
  behavior.
- Full Python runtime smoke was rerun after the HTEX worker poll-priority bridge: all 415/415 probes passed.

### Bounded v0.1 target (scope frozen)

The first deliverable is a bounded validation package, not a complete executable model of every
Parsl backend. It is complete when all of the following are true:

- the existing 622 TLC cases and 422 Python probes pass as a regression gate;
- the models cover the paper-level behaviors of logical tasks, physical attempts, dependency/Future
  propagation, executor/worker execution, retry and failure, timeout/stale results, provider
  provisioning and scale-in/out, memoization, staging/data readiness, monitoring, and `join_app`;
- each source-aligned risk in the bug ledger has a source location, a runtime reproduction when
  feasible, and a Current/Fixed TLA+ configuration or an explicit reason why modeling is not yet
  feasible;
- the final report documents the component mapping, counterexamples, limitations, and exact
  reproduction commands.

After this acceptance gate is met, the v0.1 scope is frozen. Additional executors, providers, or
implementation details become a separately tracked backlog rather than extending the completion
criteria for this deliverable.

### Latest completed stages

- Current stage: composed retry-result filtering with monitoring persistence in
  `ParslResultMonitoringAttempt`. The Fixed branch records only the current attempt as terminal
  `succeeded`; a late old-attempt result becomes stale and does not resolve the Future or database
  record. Full smoke verification passed: 629 TLC cases and 427 Python runtime probes; 666
  unittest methods are present.

- Current stage: composed heartbeat expiry with retry-generation result delivery in
  `ParslHeartbeatResultAttempt`. The Fixed branch ignores late heartbeats from expired managers,
  rejects old-attempt results, and keeps malformed/current result handling terminal. Full smoke
  verification passed: 628 TLC cases and 426 Python runtime probes; 665 unittest methods are
  present.

- Current stage: composed result delivery with physical-attempt generations in
  `ParslZMQResultAttempt`. The Fixed branch rejects malformed result payloads, ignores old
  attempts, and consumes duplicate current results once. Full smoke verification passed: 627 TLC
  cases and 425 Python runtime probes; 663 unittest methods are present.

- Current stage: composed serialized callable/object snapshots with ZMQ-style ACK-loss
  retransmission in `ParslZMQSerializedAck`. The Current branch dispatches the duplicate envelope
  twice; the Fixed branch deduplicates by task/attempt identity. Full smoke verification passed:
  623 TLC cases and 423 Python runtime probes; 659 unittest methods are present.

- Current stage: composed Flux physical-future completion, serialized result-file publication,
  user-facing wrapper cancellation, and late callback delivery in
  `ParslFluxResultFileCancellation`. The fixed TLC branch discards the stale callback while the
  runtime bridge reproduces the current `InvalidStateError` behavior already tracked as BUG-185.
  Full regression: 622 TLC cases and 422 Python runtime probes passed; 658 unittest methods are
  present.

- Current stage: added the concrete `join_app`/stage-out cancellation runtime bridge. The probe
  uses the real `DataManager` and `DataFuture` contract to show that an independent transfer can
  publish after application cancellation, matching the Current branch of
  `ParslJoinStageOutCancellation`.

- Current stage: refined `ParslJoinStageOutCancellation` with an explicit `BOUND_TO_APP` provider
  parameter. The bound-provider TLC case now verifies cancellation safety for Globus/Zip-style
  dependency wiring, while the independent-provider Current counterexample remains visible.

- Current stage: added the Zip provider bridge. The real `ZipFileStaging.stage_out` implementation
  passes the application Future as `parent_fut`, corroborating the bound-provider branch with a
  focused runtime probe.

- Current stage: added `ParslHtexWorkerPollPriority`, exposing the task-first branch of the worker
  communicator when task and result sockets are simultaneously readable. The fixed branch gives a
  ready result bounded service priority, with a deterministic fake-ZMQ runtime reproduction. The
  Current simulation reaches its 27-state counterexample, while the Fixed case passes.

- Current stage: audited monitoring database queue ordering against `DatabaseManager.start`.
  Priority messages are batch-bounded and the loop proceeds to worker/resource queues, so no new
  unbounded starvation model was added; shutdown and stale-queue observations remain separately
  modeled risks.

- Current stage: completed the full foundational Python runtime regression after adding the
  duplicate-cancellation join probe. All 412/412 probes pass against the pinned Parsl source;
  the 614-case TLC gate remains green.

- Current stage: added fixed `ParslJoinDuplicateCancellation` to the foundational TLC gate. A
  duplicated logical input now maps to one physical cancellation callback, and cancellation
  terminalizes the outer join instead of escaping as a callback exception.

- Current stage: promoted fixed `ParslCallableAliasRetry` into the foundational TLC gate. A
  callable and its aliased argument preserve shared object identity across retry snapshotting,
  while each retry captures the current source epoch.

- Current stage: promoted fixed/success `ParslStrategyBlockCapacity` configurations into
  the foundational TLC gate. Non-positive nodes-per-block capacity now has an explicit rejected
  path, while valid capacity proceeds to scaling without division failure.

- Current stage: promoted the core `ParslStrategy` model into the foundational TLC gate. The
  strategy now has an executable bounded scale-out/idle-timer/scale-in lifecycle with block
  capacity and minimum/maximum bounds.

- Current stage: promoted fixed `ParslGlobusComputeConfig` into the foundational TLC gate. The
  shared SDK resource specification and endpoint overrides are now modeled as a serialized
  critical section with default restoration after each submit.

- Current stage: promoted fixed and successful `ParslHTTPStage` configurations into the
  foundational TLC gate. In-task HTTP staging now rejects non-success status before app execution
  while preserving the successful response path.

- Current stage: promoted the core `ParslZMQ` state machine into the foundational TLC gate.
  Bounded multipart task/result messages now cover route validation, duplicate suppression,
  corruption rejection, queue delivery, and acknowledgement correlation.

- Current stage: promoted fixed `ParslPythonTimeoutCatch` into the foundational TLC gate. An
  injected walltime timeout cannot be caught and converted into a successful Future result.

- Current stage: promoted CurveZMQ certificate valid/invalid configurations into the foundational
  TLC gate. Secret keys are loaded only from private certificate directories, while invalid
  directory modes are rejected before key publication.

- Current stage: promoted fixed `ParslScaleInCancelShape` into the foundational TLC gate. A
  partial provider cancellation response now preserves the successful cancellation prefix and
  reports partial progress instead of aborting with a raw assertion.

- Current stage: promoted MPI prefix, resource-spec, and task-context configurations into the
  foundational TLC gate. MPI launchers are selected only from supported prefixes, non-positive
  resource specs are rejected before derivation, and malformed task contexts are rejected before
  scheduler admission.

- Current stage: promoted `ParslJobStatusOutputSummary` threshold, large-file, and missing-file
  configurations into the foundational TLC gate. Summary output now distinguishes no output,
  full-at-threshold content, and head/tail truncation.

- Current stage: promoted fixed `ParslJobStatusOutputReadError` into the foundational TLC gate.
  JobStatus output and summary reads now share the same defensive read-error policy instead of
  allowing permission/I/O errors to escape only through summary properties.

- Current stage: promoted HTEX `probe_addresses` timeout, empty-input, and success configurations
  into the foundational TLC gate. Address probing now distinguishes rejected empty input,
  selected responsive endpoints, and timeout failure without falsely selecting an address.

- Current stage: promoted fixed `ParslHtexZeroScaleInIdle` into the foundational TLC gate. A
  zero-count idle-only scale-in request is now an immediate no-op before scanning idle blocks.

- Current stage: promoted HTEX manager-message heartbeat and malformed-message configurations
  into the foundational TLC gate. Valid heartbeats update liveness time and reply; malformed
  messages remain isolated without mutating manager state.

- Current stage: promoted fixed `ParslTimerReentrantClose` into the foundational TLC gate. A
  timer callback can now close its own timer without attempting to join the current thread.

- Current stage: promoted fixed `ParslRetryHandler` zero-cost handling into the foundational TLC
  gate. A failed attempt now consumes at least one retry-budget unit, preventing a zero-cost
  handler from launching another attempt when `retries=0`.

- Current stage: promoted fixed `ParslInputDependencyDuplicate` into the foundational TLC gate.
  The reserved `inputs` dependency is now collected once instead of receiving duplicate callback
  registration through the generic keyword pass and the dedicated inputs pass.

- Current stage: promoted fixed `ParslDataFutureFalseyException` into the foundational TLC gate.
  Exception presence is now modeled independently of exception truthiness, so a falsey user
  exception cannot make a failed DataFuture appear successful.

- Current stage: promoted fixed `ParslDataFutureCancellation` into the foundational TLC gate.
  A cancelled parent Future now propagates terminal failure to the dependent DataFuture instead
  of publishing the represented file as available.

- Current stage: promoted `ParslSerializationSnapshot` into the foundational TLC gate. The
  serializer boundary now explicitly preserves the captured callable/argument version across
  source mutation and decode, while keeping serialization failure terminal.

- Current stage: promoted `ParslTaskTransport` normal and serialization-failure configurations
  into the foundational TLC gate. The cross-layer model requires a valid serialized task before
  dispatch, correlates results to the current attempt, and bounds retry-driven stale results.

- Current stage: promoted fixed `ParslFileTransferMonitoring` into the foundational TLC gate.
  Stage-out now requires all chunks and a version-matching source snapshot before publishing a
  ready DataFuture or persisting terminal monitoring success.

- Current stage: promoted fixed `ParslMonitoringZMQBatchClock` into the foundational TLC gate.
  Monitoring ZMQ receive batches now use a monotonic deadline, so wall-clock rollback cannot
  extend the inner receive loop beyond its one-second budget.

- Current stage: promoted fixed `ParslMonitoringUDPPickleIsolation` into the foundational TLC
  gate. An authenticated malformed pickle is discarded without killing the UDP router, allowing
  the next valid datagram to reach the monitoring queue.

- Current stage: promoted fixed `ParslMonitoringBatchThree` into the foundational TLC gate. A
  three-event monitoring transaction restores its snapshot after a failure on the second write,
  preventing partial rows from becoming visible.

- Current stage: promoted fixed `ParslMonitoringStarterConstructionFailure` into the foundational
  TLC gate. A database-constructor exception now remains the original startup failure instead of
  being masked by an unconditional close on an unbound manager variable.

- Current stage: promoted fixed `ParslFilesystemRadioAtomicity` into the foundational TLC gate.
  Monitoring pickle data is written to a temporary file and atomically renamed into the reader
  directory; write failures leave only a partial temp file and never expose it as a message.

- Current stage: promoted `ParslHeartbeatProvider` into the foundational TLC gate. Provider
  UNKNOWN status is kept distinct from manager heartbeat expiry; provider terminal states revoke
  executor admission and clean up in-flight tasks.

- Current stage: promoted `ParslJoinThreeList` into the foundational TLC gate. Three distinct
  logical inner Futures may complete in any order, while the outer result reconstructs all four
  ordered list positions, including a duplicate reference.

- Current stage: promoted fixed and stable `ParslJoinListMutation` configurations into the
  foundational TLC gate. Join registration now snapshots mutable list membership before callbacks;
  the no-mutation path remains a separate positive baseline, while the Current aliasing case stays
  as a documented counterexample.

- Current stage: promoted `ParslResultRace` into the foundational TLC gate. Physical attempt
  failure, retry, late success, and result delivery are correlated by attempt id; stale results
  cannot resolve the logical Future after a newer attempt is current.

- Current stage: promoted fixed `ParslJoinThreeCancellation` into the foundational TLC gate. A
  cancelled member of a three-Future list now yields terminal outer failure while the callback
  handles `CancelledError` instead of escaping and leaving the join pending.

- Current stage: promoted fixed `ParslJoinRunningCancellation` into the foundational TLC gate.
  Cancellation of an already-running inner Future now resolves the outer join as terminal
  failure, and the callback cannot escape as an unhandled exception.

- Current stage: promoted fixed `ParslJoinRetryDuplicates` into the foundational TLC gate. The
  model preserves every duplicate input position after an inner physical retry while still
  observing one logical Future and one final value.

- Current stage: promoted `ParslJoinRetry` into the foundational TLC gate. Logical inner Futures
  now remain unresolved across non-final physical attempts; the outer join observes only the final
  result or final failure and preserves ordered aggregation.

- Current stage: promoted fixed `ParslProviderExecutorTimedMonitoring` into the foundational TLC
  gate. This cross-component model composes provider provisioning, manager heartbeat expiry,
  task timeout/retry, stale physical results, scale-in admission, and terminal DB persistence.

- Current stage: promoted fixed `ParslMonitoringVersionedBatch` into the foundational TLC gate.
  The model checks transaction rollback after a duplicate event and preserves a per-task version
  high-water mark so a late older status cannot overwrite a newer terminal row.

- Current stage: promoted fixed `ParslMonitoringThreshold` into the foundational TLC gate. The
  model requires a zero-threshold batch to consume an available monitoring event, while the
  Current configuration remains as the documented queued-message counterexample.

- Current stage: promoted the busy and idle `ParslHtexWorkerWatchdog` configurations into the
  foundational TLC gate. The model separates physical worker death from logical task state,
  emits one WorkerLost result for a busy worker, and restarts idle capacity without a task result.

- Current stage: promoted the fixed `ParslHtexHeartbeatVersion` configuration into the
  foundational TLC gate. The combined model rejects task admission after registration or
  heartbeat failure becomes observable, orders one fatal result, and drains outstanding work.

- Current stage: promoted `ParslHeartbeatBoundary` into the foundational TLC gate. The compact
  model checks strict heartbeat expiry, heartbeat reset at the exact threshold, in-flight task
  accounting when a manager expires, and suppression of post-loss heartbeats.

- Current stage: promoted `ParslStagingProviderDispatch` into the foundational TLC gate. The
  model checks first-capable provider selection, terminal `None` staging results, Future-backed
  dependency admission, and explicit failure when no provider can stage the file.

- Current stage: promoted the fixed-empty and successful `ParslGlobusTransferFailure`
  configurations. The staging model now requires a terminal Globus failure to become a reported
  transfer failure even when no diagnostic event is available, while preserving successful
  transfer handling.

- Current stage: promoted the fixed and normal `ParslSerializationFrameCount` configurations
  into the foundational TLC gate. The model now checks that an apply message with an extra frame
  is rejected before any payload decode, while a valid three-frame message decodes exactly once.

- Current stage: promoted the fixed and valid `ParslSerializationLength` configurations. The
  length model now distinguishes a truncated payload, which must be rejected, from a complete
  five-byte payload, which may be accepted without violating `LengthSafety`.

- Current stage: promoted `ParslNestedJoin` into the foundational TLC gate. The two-level
  composition now checks that an outer `join_app` waits for the inner join, preserves the inner
  list order, and propagates a nested leaf failure only after the inner handle is terminal.

- Current stage: added `ParslRadicalPilotDecodeFailure`, covering malformed serialized Python
  result payloads in the RP `DONE` callback. The Current branch lets decode failure escape and
  leaves the Future pending; the Fixed branch resolves a terminal failure. The focused TLC model
  and runtime probe pass.

- Current stage: added `ParslFluxShutdownLifecycle`, covering shutdown before FluxExecutor
  startup. The Current branch joins an unstarted submission thread and raises `RuntimeError`; the
  Fixed branch treats the unstarted executor as quiescent. TLC and the concrete FluxExecutor
  runtime probe pass without requiring a Flux service.

- Current stage: added `ParslThreadExecutorLifecycle`, covering failed thread-pool startup and
  cleanup. The Current branch exposes a second raw shutdown error when `start()` never created
  the underlying pool; the Fixed branch makes shutdown safe for the unstarted state. TLC and the
  installed ThreadPoolExecutor runtime probe pass.

- Current stage: added `ParslStrategyIdleClock`, which connects idle-resource scale-in to the
  wall-clock/monotonic-clock boundary. The Current branch reproduces suppression of scale-in
  after a wall-clock rollback; the Fixed branch evaluates the elapsed horizon monotonically.
  The focused TLC counterexample, Fixed run, and real `Strategy` runtime probe pass.

- Current stage: added `ParslJoinStageOutCancellation`, a compact composition of application
  completion, stage-out publication, outer cancellation, and a late stage-out callback. The
  Current branch reproduces publication after cancellation; the Fixed branch rejects that stale
  publication and passes the bounded TLC exploration. This is an abstract safety baseline rather
  than a claim that every Parsl staging provider currently exposes the same race.

- Current stage: promoted `ParslZipStageOut` as the archive publication boundary. Archive write,
  source cleanup, retry after cleanup failure, source-version change, and duplicate-member handling
  are explicit; the Fixed branch replaces an existing member rather than appending a duplicate.
  The fixed TLC configuration and six real ZIP staging probes pass.

- Current stage: promoted `ParslLSFSubmit` as the LSF `bsub` submission lifecycle. Script writing,
  scheduler failure, empty/malformed successful output, and valid marker/job-id registration are
  separate paths; only valid output publishes a resource. Three TLC configurations and five LSF
  submit runtime probes pass.

- Current stage: promoted `ParslGridEngineSubmit` as the basic qsub submission lifecycle.
  Script publication, command failure, empty successful output, and valid job-id registration
  are separate terminal paths; only the valid path publishes a pending resource. All three TLC
  configurations and the concrete Grid Engine submit probes pass.

- Current stage: promoted `ParslLocalProviderExitStatus` as the local `.ec` marker boundary.
  In-flight `-`, numeric exit codes, malformed contents, process liveness, and cancellation are
  distinct observations; numeric exit evidence wins over liveness/cancel and terminal status is
  not regressed by later marker changes. TLC and both LocalProvider runtime probes pass.

- Current stage: promoted `ParslCondorCancel` as the Condor cancellation boundary. Chunked
  scheduler cancellation updates only locally owned IDs, treats unknown IDs as absent rather
  than crashing, and returns per-request success/failure consistently. Both success/failure TLC
  configurations and the three concrete runtime probes pass.

- Current stage: promoted `ParslExecutorProvider` as the compact provisioning/admission model.
  Provider block allocation, manager registration, worker readiness, task submission, dispatch,
  provider failure, drain/recovery, and block-granular scale-in are separate transitions. The
  bounded model and provider-worker runtime bridges pass while preserving admission and ownership
  invariants.

- Current stage: promoted `ParslProviderStatusBatch` as the provider-neutral batched status
  projection boundary. It models bounded scheduler batches, atomic preservation on command failure,
  translation of reported states, and explicit completion of jobs absent from a successful batch.
  The full bounded TLC configuration and targeted Slurm status probes pass.

- Current stage: promoted `ParslClusterSubmitScript` as the common scheduler-script boundary.
  Valid template substitution publishes the script; missing template keys map to a scheduler
  argument error, and target I/O failures map to a path error without publishing a partial script.
  All three TLC configurations and the real `ClusterProvider` runtime probes pass.

- Current stage: promoted `ParslTasksOutgoing` as the HTEX task-channel sender boundary. A
  `put()` sends one Python object over the DEALER socket while the sender is open; close tears down
  the socket/context and later sends are outside the valid wrapper state. The normal TLC model and
  the real sender/close probes pass, with the close-race model retaining the source-level race.

- Current stage: promoted `ParslResultsIncoming` as the minimal HTEX result-channel boundary. A
  readable DEALER socket yields one multipart message, a poll timeout yields no message, and
  close terminates the receiver context. Both TLC configurations and the real wrapper probes pass;
  the separate close-race model continues to document post-close access behavior.

- Current stage: promoted `ParslJoinMonitoring` as the first compact join/monitoring composition.
  It combines memoized, staged-file, and compute inner Futures with outer join finalization,
  versioned monitoring events, queue reordering, bounded database-write failure, and terminal
  status persistence. The bounded TLC configuration passes all join, data-readiness, and
  monitoring invariants.

- Current stage: promoted `ParslMonitoringDelivery` as the compact logical-task to database
  event path. It models versioned status events, asynchronous queue delivery, reordering, and
  stale-write rejection at the database high-water mark. The Current configuration reproduces
  an older event overwriting a newer record; the Fixed configuration is smoke-gated, and the
  monitoring status-history/database runtime probes pass.

- Current stage: promoted `ParslJoinInternalExecutor` as the executor-admission boundary for
  `join_app`. The fixed branch routes the outer join through `_parsl_internal`, while the Current
  branch reproduces accidental dispatch through the user's `all` executor set. The focused TLC
  model and existing `join_app` runtime test both pass.

- Current stage: promoted `ParslGlobusStageDependency` as the explicit stage-in/stage-out Future
  dependency boundary. Stage-in cannot start until its parent DataFuture is ready, and stage-out
  cannot start until the application Future is done. The bounded TLC model and both real Globus
  staging dependency probes pass.

- Current stage: promoted `ParslMultiOutputStageOut` as the small multi-output DataFuture gate.
  Each output stage-out Future is independently represented but remains gated by the same
  application Future; a dependent consumer can run only after its own output is published. The
  early-publication configuration reproduces visibility before application completion, while the
  normal configuration passes the bounded TLC check and the real `DataManager.stage_out` probe.

- Current stage: promoted `ParslSerializationWire` as the concrete apply-message framing
  boundary. It requires callable, args, and kwargs buffers to serialize, receive the expected
  `C2`/`02` headers, preserve length validity, and decode in order before dispatch. The failure
  configuration also checks that an unserializable buffer rejects the complete message.

- Current stage: promoted `ParslThreeConcurrentTimeouts` as the multi-task timeout boundary.
  Three independent logical tasks have distinct deadlines and retry generations; a late result
  is accepted only when its task and generation are still current. The Current configuration
  reproduces acceptance of a stale result, while the Fixed configuration preserves independent
  task terminal state and passes the bounded TLC exploration.

- Current stage: promoted the compact integrated `ParslClock` smoke model. It combines logical
  wall-clock ticks, heartbeat send/deliver/drop, manager expiry/recovery, task deadlines,
  physical-attempt retry, and stale-result classification in one bounded state machine. The
  smoke configuration uses one worker, one retry, and a three-tick horizon while checking clock,
  heartbeat, timeout, result, and Future safety invariants.

- Current stage: promoted `ParslHtexMonitoringMessage` as the HTEX optional-monitoring-frame
  boundary. The Current configuration reproduces a crash when an optional monitoring payload is
  handled on a path where monitoring is disabled; the Fixed configuration ignores that payload
  while preserving task-result forwarding. The TLC counterexample, fixed run, and Python runtime
  probe all pass, and the fixed configuration is now part of the foundational smoke gate.

- Current stage: added the compact `ParslMonitoringDBRetry` insert primitive. The operational
  configuration models rollback/retry and single-row persistence; the integrity configuration
  models a non-retry drop. Both configurations are now part of the TLC smoke gate.

- Current stage: promoted `ParslProviderPolling` as the provider-neutral lifecycle baseline. It
  separates submit, status, transient API failure, unknown status, and cancellation rollback
  before scheduler-specific provider behavior is refined.

- Current stage: promoted the concrete `ParslLocalProvider` lifecycle baseline. The fixed branch
  preserves `.ec` exit-marker precedence and strict cancellation semantics; the runtime bridge
  exercises the corresponding LocalProvider status behavior.

- Current stage: added `ParslKubernetesLifecycle`, a cross-boundary provider model combining pod
  phase translation, read errors, cancellation, and late poll responses. The Current branch
  produces stale-terminal and hidden-error counterexamples; the Fixed branch is smoke-gated.

- Current stage: added a re-entrant Kubernetes runtime probe for a poll/cancel race. It reproduces
  BUG-282 against the installed provider: `_status()` can publish a late terminal pod phase after
  `cancel()` has already published `CANCELLED`.

- Current stage: promoted `ParslJoinCallableTransport` into the TLC gate. It composes callable
  snapshots, retry generations, stale result rejection, logical Future completion, and ordered
  duplicate join positions.

- Current stage: promoted `ParslJoinImmediateCallback` into the TLC gate. It models an already
  completed dependency invoking its callback during registration and verifies that outer join
  completion remains gated by the remaining dependency.

- Current stage: promoted `ParslFunctionObjectTransport` into the TLC gate. It models callable
  closure/object snapshot capture before queueing, source mutation while in flight, and execution
  from the decoded snapshot.

- Current stage: promoted `ParslHtexResultForwarding` into the TLC gate. It models manager task
  ownership across serialized result forwarding, send failure, and bounded retry; the Fixed branch
  prevents a failed ZMQ send from silently losing the task record.

- Current stage: promoted the full-horizon `ParslTimedHeartbeatFixed` configuration. The smoke gate
  now checks both the short and four-tick paths for heartbeat expiry, task timeout, and late-result
  classification.

- Current stage: promoted the normal-length `ParslHTTPSeparateContentLength` configuration. The
  staging gate now checks both short-response rejection and successful publication when received
  bytes exactly match the declared `Content-Length`.

- Current stage: promoted `ParslHtexResultQueue` into the executor gate. It models malformed,
  duplicate, and terminal Future result frames, requiring failed messages to resolve or preserve
  ownership without killing the result worker.

- Current stage: promoted the present-manager `ParslHtexManagerDrain` path. The smoke gate now
  checks the normal drained-manager acknowledgement/removal behavior alongside the stale-ID Fixed
  path and its existing runtime probe.

- Current stage: promoted the normal `ParslMonitoringDBInsertPresent` configuration. The monitoring
  gate now checks first-write persistence separately from duplicate-event idempotence/drop paths.

- Current stage: promoted the normal `ParslHTTPSeparateStatus` configuration. The staging gate now
  checks successful 2xx response publication separately from non-success response rejection.

- Current stage: promoted the one-block `ParslProviderThreeBlockOwnershipSmokeFixed` configuration.
  The provider gate now checks the bounded provisioning/assignment/scale-in ownership path in both
  the three-block and minimal smoke-sized state spaces.

- Current stage: promoted both invalid-admission and valid-start configurations for
  `ParslThreadExecutorThreadCount`. The executor gate now checks early rejection of zero workers
  and successful construction with one worker.

- Current stage: promoted `ParslGoogleCloudStatusPresent`. The provider gate now checks normal
  `RUNNING` translation separately from unknown-status tolerance and remote-failure handling.

- Current stage: promoted `ParslJoinImmediateCallback` into the TLC gate. It models an already
  completed dependency invoking its callback during registration and verifies that outer join
  completion remains gated by the remaining dependency.

- Current stage: promoted `ParslLocalProviderStatusScope`. The Fixed model passed TLC and the
  Current branch reproduced the stale unrelated-resource query failure; the targeted runtime
  probe passed against the installed LocalProvider implementation.

- Current stage: promoted `ParslLsfSubmitJobId`. The Fixed model passed TLC and the Current branch
  reproduced publication of a malformed scheduler token; the targeted LSF runtime probe passed.

- Current stage: promoted `ParslLSFCancel`. The Fixed model passed TLC and the Current branch
  reproduced the unknown-local-ID cancellation crash; three targeted runtime tests passed.

- Current stage: promoted the base `ParslKubernetesCancel` response model. The Fixed model passed
  TLC and the Current branch reproduced a returned-error response being marked cancelled; the
  existing Kubernetes cancellation runtime probes cover the concrete source boundary.

- Current stage: promoted the base `ParslCondorSubmit` output model. The Fixed model passed TLC
  and the Current branch reproduced empty/malformed successful output reaching raw parser failure;
  six targeted Condor submit runtime tests passed.

- Current stage: promoted `ParslGridEngineCancel`. The Fixed model passed TLC and the Current
  branch reproduced the unknown-local-ID `qdel` crash; three targeted runtime tests passed.

- Current stage: promoted `ParslPBSProSubmit`. The Fixed model passed TLC and the Current branch
  reproduced successful submission with no trackable resource; three targeted PBS Pro submit
  runtime tests passed.

- Current stage: added `ParslProviderCancelFuture`, the first focused cancellation composition
  model connecting provider state, one physical attempt, Future terminal state, late-result
  handling, and monitoring persistence. Fixed passed TLC; Current produced the expected
  cancellation/Future consistency counterexample.

- Current stage: added `ParslProviderCancelRetryMonitoring`, extending cancellation through
  provider loss, retry generation 2, stale generation-1 result delivery, and monitoring
  persistence. Fixed passed TLC; Current reproduced the expected cancellation consistency
  counterexample.

- Current stage: added `ParslJoinCancelRetryGeneration`, lifting cancellation, retry generation,
  stale results, and monitoring consistency to a two-dependency join. Fixed passed TLC; Current
  reproduced the cancelled-join mutation counterexample.

- Current stage: promoted the compact `ParslJoinComplete` Future-propagation model. Fixed passed
  TLC and the Current branch reproduced duplicate-list position loss; existing join runtime
  probes cover ordered values, failure propagation, and duplicate references.

- Current stage: promoted `ParslTripleNestedJoin`, extending dependency blocking and failure
  propagation to three nested join levels. Fixed passed TLC; Current reproduced premature J2
  evaluation with an unresolved input.

- Current stage: promoted `ParslMessageCorrelationThree`, extending ZMQ/serialization coverage
  to four logical tasks, two attempts, multipart delivery, retargeting, duplicates, and stale
  results. Fixed passed TLC; Current reproduced incorrect resolution of an obsolete/retargeted
  message.

- Current stage: promoted `ParslHeartbeatClockJump`. Fixed passed TLC and two targeted runtime
  probes passed; Current reproduced both forward-jump premature expiry and backward-jump delayed
  expiry behavior.

- Current stage: promoted `ParslMonitoringDBInsert`. Fixed passed TLC and three targeted runtime
  probes passed; Current reproduced duplicate STATUS event loss after an integrity rollback.

- Current stage: promoted `ParslHTTPPartialCleanup`. Fixed passed TLC and the targeted HTTP
  streaming runtime probe passed; Current reproduced partial destination publication after a
  later chunk failure.

- Current stage: promoted `ParslFileCleanCopy`. Fixed passed TLC and the targeted runtime probe
  passed; Current reproduced site-local path aliasing in a clean DataFuture copy.

- Current stage: promoted `ParslBadStateTerminalFuture`. Fixed passed TLC and two targeted runtime
  tests passed; Current reproduced a completed Future aborting bad-state failure fan-out.

- Current stage: promoted `ParslTorqueTasksPerNode`. Fixed passed TLC and the targeted runtime
  probe passed; Current reproduced non-positive `tasks_per_node` reaching launcher construction.

- Current stage: promoted `ParslLocalTasksPerNode`. Fixed passed TLC and the targeted runtime
  probe passed; Current reproduced zero `tasks_per_node` launching a failed local job.

- Current stage: promoted `ParslKubernetesUnknownJob`. Fixed passed TLC and the targeted runtime
  probe passed; Current reproduced stale status lookup raising a missing-resource error.

- Current stage: promoted `ParslPBSProStatus`. Fixed passed TLC and three targeted runtime tests
  passed; Current reproduced a foreign scheduler ID crashing the PBS Pro status poll.

- Current stage: promoted `ParslSlurmSubmit`. Fixed passed TLC and three targeted runtime tests
  passed; Current reproduced a successful regex match without a named job-id group crashing
  submission.

- Current stage: promoted `ParslKubernetesSubmit`. Fixed passed TLC and two targeted runtime tests
  passed; Current reproduced a newly created Pending pod being recorded as RUNNING.

- Current stage: promoted `ParslTorqueCancel`, making the provider's successful-cancel state
  convention explicit. Fixed passed TLC; three targeted Torque cancellation runtime tests passed.

- Current stage: promoted the positive `ParslAzureStatus` translation baseline, keeping the
  pending/running/terminal/unknown mapping in the foundational gate alongside Azure failure and
  ordering models.

- Current stage: added `ParslJoinStageRetry`, combining per-dependency file publication,
  physical-attempt retry, late-result correlation, and outer join completion. The Fixed
  configuration passed TLC; the Current configuration produced stale-result and unsafe staging
  counterexamples.

- Current stage: promoted the existing `ParslJoinTimedMonitoring` Fixed case into the
  foundational gate, covering heartbeat expiry, task timeout, cancellation, late completion,
  and monitoring persistence together with join data readiness.

- Current stage: promoted the HTEX unknown-result-type Fixed case, ensuring malformed result
  frames do not terminate the result worker before independent valid Futures are delivered.

- Current stage: promoted the HTEX watchdog-result race Fixed case, ensuring worker-loss
  synthesis cannot duplicate a result already published for the same task.

- Current stage: promoted the Flux inflight-submission Fixed case, ensuring a jobspec failure
  after queue dequeue completes the affected Future and leaves no orphaned inflight task.

- Current stage: promoted the Flux cancel-before-bind Fixed case, ensuring cancellation is
  propagated to the underlying Future and late callbacks cannot write a cancelled wrapper.

- Current stage: promoted the Flux late-success-on-cancelled-wrapper Fixed case, covering the
  complementary terminal callback race alongside the existing late-failure case.

- Current stage: promoted the TaskVine resource-spec-shape Fixed case, requiring malformed
  submit resource specifications to fail as controlled admission errors.

- Current stage: promoted the Work Queue category-schema Fixed case, ensuring a valid `category`
  resource reaches the executor mapping branch rather than being rejected by the schema.

- Current stage: promoted the Work Queue resource-spec-shape Fixed case, requiring validation
  before task-directory and Future-registration side effects.

- Current stage: promoted the HTEX address-probe-timeout Fixed case, preserving explicit zero
  timeout values instead of silently substituting the worker default.

- Current stage: promoted the provider polling clock-rollback Fixed case, ensuring a backward
  wall-clock step cannot suppress a due provider status poll.

- Current stage: promoted the AWS provider missing-instance Fixed case, requiring every requested
  instance to receive a deterministic status observation even when EC2 omits it.

- Current stage: promoted the Azure missing-local-cancellation Fixed case, treating successful
  remote deletion plus absent local bookkeeping as an idempotent cancellation.

- Current stage: promoted the Slurm foreign-status Fixed case, isolating unrelated scheduler rows
  instead of crashing the entire provider status poll.

- Current stage: promoted the Condor malformed-status-line Fixed case, preserving known resource
  state while skipping truncated scheduler records.

- Current stage: promoted the Grid Engine status-batch Fixed case, isolating malformed scheduler
  records so later valid jobs in the same poll still update.

- Current stage: promoted the Grid Engine single-record status Fixed case, retaining the direct
  malformed-line parser boundary alongside the batch composition model.

- Current stage: promoted the Torque foreign-status Fixed case, isolating unrelated scheduler
  lines instead of terminating the provider poll.

- Current stage: added `ParslJoinProviderResultMonitoringDB`, lifting provider failure/retry,
  stale inner results, two-dependency join completion, and monitoring persistence into one model.
  The Fixed configuration passed TLC; the Current configuration produced the expected provider
  and stale-inner-result counterexamples. The existing 406-entry runtime gate stays green.

- Current stage: added `ParslProviderResultMonitoringDB`, extending provider failure/retry and
  stale-result correlation with queued/persisted monitoring status and duplicate persistence.
  The Fixed configuration passed TLC; the Current configuration produced provider, stale-result,
  and terminal-row-loss counterexamples. The existing 406-entry runtime gate stays green.

- Current stage: added `ParslProviderResultRetryRace`, combining provider poll failure, executor
  collector loss, physical-attempt retry, late result delivery, and monitoring terminal state.
  The Fixed configuration passed TLC; the Current configuration produced the expected provider
  loss and stale-resolution counterexamples. The existing 406-entry runtime gate remains green.

- Current stage: promoted Bash app, cluster script, JobStatus, MPI, HTEX probe, Radical bulk
  shutdown, and Timer reentrant-close probes. Twenty-three targeted tests passed, and the
  affected runtime suffix (255–406) passed after insertion; the prior prefix (1–254) was already
  green.

- Current stage: promoted provider-status/cancellation probes for bad-state callback mutation,
  Grid Engine, LSF, PBS Pro, Slurm, Torque, and LocalProvider. Fourteen targeted tests passed,
  and the affected runtime suffix (246–394) passed after insertion; the prior prefix (1–245) was
  already green.

- Current stage: promoted core dataflow/dispatch probes for Future dependency blocking, duplicate
  dependency collection, apply-message arity, retry-handler accounting, and duplicate provider
  job-ID ownership. Seven targeted tests passed, and the affected runtime suffix (241–385)
  passed after insertion; the prior prefix (1–240) was already green.

- Current stage: promoted TaskVine shutdown/resource-shape, Work Queue resource-shape, and
  Radical-Pilot failure-fanout probes. Four targeted tests passed, and the affected runtime
  suffix (237–380) passed after insertion; the prior prefix (1–236) was already green.

- Current stage: promoted scheduler-submit runtime probes for Grid Engine, LSF, PBS Pro, Slurm,
  and Torque. Seventeen targeted tests passed, and the affected runtime suffix (230–376) passed
  after insertion; the prior prefix (1–229) was already green.

- Current stage: promoted HTEX transport ingress/egress probes for `TasksOutgoing`,
  `ResultsIncoming`, post-close sends, and executor-side `execute_task` decoding. Nine targeted
  tests passed, and the affected runtime suffix (226–369) passed after insertion; the prior
  prefix (1–225) was already green.

- Current stage: promoted CommandClient reply/timeout and expired-deadline probes, plus Timer
  interval and walltime conversion boundaries. Five targeted tests passed, and the affected
  runtime suffix (222–365) passed after insertion; the prior prefix (1–221) was already green.

- Current stage: promoted TaskVine and Work Queue result-file/Future propagation probes plus
  `File.filepath` resolution. Fourteen targeted tests passed, and the affected runtime suffix
  (219–361) passed after insertion; the prior prefix (1–218) was already green.

- Current stage: promoted serializer-registry precedence and cyclic Python-object round-trip
  coverage. The two targeted runtime probes passed, the new cyclic-object TLC case passed, and
  the affected runtime suffix (217–358) passed after insertion; the prior prefix (1–216) was
  already green.

- Current stage: promoted memoization runtime probes for duplicate-call reuse, closure-content
  identity, heterogeneous dictionary-key hashing, and unknown `ignore_for_cache` names. Four
  targeted tests passed, and the affected runtime suffix (213–356) passed after insertion; the
  prior prefix (1–212) was already green.

- Current stage: promoted the `Strategy` runtime bridge for initial capacity, overload scale-out,
  idle scale-in with a minimum block floor, and invalid zero-nodes-per-block input. The targeted
  four tests passed, and the affected runtime suffix (212–352) passed after insertion; the prior
  prefix (1–211) was already green.

- Current stage: promoted BlockProvider bad-state propagation probes for outstanding Future
  fan-out, completed-Future ordering, and callback-driven task-map mutation. Four targeted tests
  passed, and the affected runtime suffix (209–351) passed after the new entries were inserted;
  the prior prefix (1–208) was already green.

- Current stage: promoted Grid Engine and Torque cancellation, LSF missing-job status, and
  Radical Pilot removed-task callback probes. The targeted seven tests passed; the full runtime
  inventory passed in two contiguous segments through 348/348, while the existing Fixed TLC
  models remain covered by the 382-case gate.

- Current stage: promoted duplicate-status runtime probes for Grid Engine, LSF, Slurm, and
  Torque. All four current implementations reproduce the expected `ValueError`/`KeyError`
  failure on duplicate scheduler rows; their Fixed TLC models remain green. The complete
  foundational runtime suite passed 344/344 entries.

- Current stage: deepened `ParslClusterProviderUnknownJob` to a mixed status poll containing a
  valid known job and a stale unknown ID. The Fixed branch preserves the valid RUNNING update
  while returning MISSING for the stale ID; the Current branch still produces the raw CRASH/
  `KeyError` behavior. The runtime probe and complete foundational smoke suites passed 340/340
  runtime entries and 382/382 TLC cases.

- Current stage: promoted Work Queue and TaskVine duplicate/late-result collector boundaries.
  The fixed models ignore an already-consumed task identifier and preserve unrelated Futures;
  the Current models retain the collector-exit and unrelated-failure counterexample. Both
  runtime probes passed, and the complete foundational smoke suites passed 382/382 TLC cases
  and 339/339 runtime entries.

- Current stage: promoted monitoring shutdown boundaries into the foundational gate. The
  external-queue model checks that a stale `empty()` observation cannot strand a message, while
  the UDP drain-clock model checks that wall-clock rollback cannot extend shutdown indefinitely.
  Both fixed configurations passed TLC, both runtime probes passed, and the complete foundational
  smoke suites passed 380/380 TLC cases and 337/337 runtime entries.

- Current stage: added `ParslProviderStagingAdmission`, a compact cross-component model for
  provider provisioning, chunked file publication, DataFuture readiness, task admission, and
  scale-in/retry. The fixed configuration passed TLC; the current configuration produces the
  expected counterexamples for premature publication and capacity loss. The new staging-provider
  runtime bridge passed, and the complete foundational runtime suite passed 335/335.

- Current stage: promoted eleven concrete provider runtime bridges into the foundational gate:
  HTEX submit, Kubernetes cancel/submit, Azure and Google Cloud cancel, Condor cancel/empty
  submit, Flux cleanup/status/working-directory, and LocalProvider submit cleanup. The targeted
  provider batch ran 21 tests, and the complete foundational runtime suite passed 334/334.

- `e9503ff`: PBS Pro status-batch isolation. A malformed scheduler record must not prevent an
  independent valid record in the same response from being processed.
- `27a9e65`: monitoring worker cross-table atomicity. A committed `STATUS` write must not remain
  visible after the corresponding `TRY` update fails.
- `aab331c`: HTEX malformed-task continuation. A malformed task envelope must not stop the ZMQ
  ingress loop before a later valid task is queued.
- `656c5e7`: Globus token-schema validation. An incomplete cached service mapping must not expose
  a raw `KeyError` during authorizer construction.
- `b8c3e41`: Globus initialization race. Concurrent creation of `~/.parsl` must not turn ready
  directory state into `FileExistsError`.
- `00c18d9`: HTEX serialization-failure normalization. Non-`TypeError` serializer failures must
  not escape the public submit boundary as raw implementation exceptions.
- `7692d96`: recorded the HTEX serialization stage and its durable smoke inventory.
- `270d093`: refined HTEX result decoding with a corrupt-then-valid batch sequence; a bad frame
  must not strand the later Future.
- `9f9b4c1`: JobStatusPoller executor isolation. A provider/status failure in one executor must
  not suppress independent executors in the same polling tick.
- `1cc300f`: monitoring internal-queue drain. Shutdown must not exit the database loop while a
  pending internal message remains after a stale `empty()` observation.
- `af476ac`: ThreadPoolExecutor empty resource-spec validation. A falsy non-mapping resource
  specification must not bypass executor input validation.
- `0f6ccec`: HTEX callable-object serialization errors. A callable without `__name__` must not
  mask the original serialization TypeError with an `AttributeError`.
- `7178406`: extended the callable-object serialization-error refinement to Flux, confirming the
  same safe error-reporting condition across two concrete executors.
- Current stage: refined BUG-018 for TaskVine and Work Queue failure reports. A cancelled Future
  can raise from `set_exception` just as it can from `set_result`; both current models produce a
  two-state counterexample, while both fixed models complete in seven generated/four distinct
  states. Runtime probes exercise both collector branches.
- Current stage: refined BUG-135 for Radical-Pilot late `FAILED` callbacks. A callback arriving
  after cancellation can raise through `set_exception` just like the existing `DONE` path; the
  failure Current model produces a four-state counterexample and the Fixed model passes.
- Current stage: added MPI malformed-result cleanup. A corrupt pickle currently escapes
  `MPITaskScheduler.get_result`, leaving allocated nodes held while the ferry loop continues;
  the Current model produces a two-state leak counterexample and the Fixed model releases the
  allocation while publishing a terminal decode failure.
- Current stage: completed the provider ledger mapping for Slurm cancellation. Existing
  `ParslSlurmCancel` and `ParslSlurmCancelBatch` models plus the runtime probe document that a
  successful remote `scancel` can still raise on a stale local ID after partially updating a
  batch; this is now tracked as BUG-277.
- Current stage: refined BUG-084 for truthy user equality. An invalid join return whose
  `__eq__([])` returns `True` enters the empty-list branch and leaves the outer Future pending;
  the new Current model has a three-state counterexample and the Fixed model passes.
- Current stage: added `ParslJoinPartialCancellation`, which forces one list member to be
  observed successfully before a second member is cancelled. The Current model produces an
  eight-state/5-distinct callback-escape counterexample; the Fixed model passes in 10/5 states.
- Verification stage: the complete foundational regression passed after the join refinement:
  all 362 TLC smoke cases passed with `TLC_SIMULATE=10`, and all 233 Python runtime probes
  passed against the installed Parsl source. The runtime run emitted only existing resource
  warnings from temporary Parsl log handles; no test failed.
- Current stage: added `ParslHtexCancelledFailureResult`, the failure-payload counterpart to
  `ParslHtexCancelledResult`. The current HTEX result worker can escape after `set_exception`
  rejects a cancelled Future and its recovery call rejects again; the Current model produces a
  two-state counterexample, the Fixed model passes in seven generated/four distinct states, and
  the runtime probe reproduces the stranded later failure Future.
- Current stage: added `ParslFluxLateFailureCancelledFuture`, the failure counterpart to the
  existing late-success cancellation model. `_complete_future` can call `set_exception` on a
  cancelled wrapper after an underlying Flux job fails; the Current model produces a two-state
  counterexample, the Fixed model passes in four generated/two distinct states, and the concrete
  callback probe reproduces the `InvalidStateError`.
- Current stage: bridged the existing BUG-018 failure-path models to concrete collector probes.
  Work Queue and TaskVine each now exercise a cancelled first failure report followed by a live
  report; the current collector aborts and its finalizer fails the unrelated Future, matching the
  Current TLA+ semantics. The targeted result suites pass 11/11 tests.
- Current stage: added `ParslFluxCancelRunningRace`, which models `FluxFutureWrapper.cancel()`
  while the wrapper is RUNNING but the underlying Flux future still accepts cancellation. The
  Current model produces a two-state `NoRawCancelError` counterexample, the Fixed model passes in
  four generated/two distinct states, and the runtime probe reproduces the raw `RuntimeError` plus
  the inconsistent unfinished-wrapper state.
- Current stage: added `ParslScaleInResultShape` for malformed provider cancellation responses.
  A short boolean result list currently reaches a raw `_filter_scale_in_ids` assertion; the
  Current model produces a two-state counterexample, the Fixed model passes in four generated/two
  distinct states, and the runtime probe reproduces the assertion directly.
- Current stage: added `ParslAwsInstanceStateShape` for an empty EC2 reservation in
  `AWSProvider.get_instance_state`. The Current model produces a two-state `NoRawIndexError`
  counterexample, the Fixed model passes in four generated/two distinct states, and the provider
  probe reproduces the concrete `IndexError`.
- Current stage: added `ParslHtexRegistrationBlockId` for a null manager registration block ID.
  The current interchange reaches an internal assertion after decoding the ZMQ registration;
  the Current model produces a two-state `NoRawAssertion` counterexample, the Fixed model passes
  in four generated/two distinct states, and the manager-message runtime suite now passes 6/6.
- Current stage: promoted the existing `ParslMonitoringResourceHistory` model and SQLite bridge
  into the foundational smoke inventory. It checks append-only RESOURCE rows, out-of-order sample
  delivery, duplicate primary-key rejection, and latest-by-timestamp selection; the model and
  runtime probe are now part of the 369/236 regression gate.
- Current stage: promoted `tests/test_join_three_list_runtime.py` into the foundational runtime
  gate. The probe confirms three distinct inner Futures preserve four ordered output positions,
  including a duplicate reference, matching the existing `ParslJoinThreeList` model.
- Current stage: promoted six existing serialization and staging runtime bridges into the
  foundational gate. The probes now exercise closure/object snapshotting, serializer frame and
  header validation, clean-copy normalization, filesystem-radio atomic publication, and HTTP
  staging failure behavior against the installed Parsl source.
- Current stage: promoted eight clock/heartbeat runtime bridges into the foundational gate. The
  probes cover HTEX drain and heartbeat message timing, address-probe timeout propagation,
  provider polling after clock rollback, resource-monitor sampling, and monitoring batch deadlines.
- Current stage: promoted ten concrete provider runtime bridges into the foundational gate. The
  probes cover Local process and status lifecycle, AWS reservation/status shapes, Azure resource
  bookkeeping, and malformed/unknown job responses from Condor, Slurm, PBSPro, and Kubernetes.
- Current stage: promoted four join-composition runtime bridges into the foundational gate. The
  probes cover serialized callable values, nested error-root selection, callback-time list mutation,
  and duplicate input positions across retry attempts.
- Current stage: promoted five cross-component runtime bridges into the foundational gate. The
  probes cover HTEX result decode failure, result-forwarding ownership loss, optional monitoring
  message handling, scheduler-command timeout cleanup, and negative provider scale-in behavior.
- Current stage: added `ParslJoinRetryStaleResult`, a cross-layer TLA+ model for two logical join
  dependencies and bounded physical attempts. The Current branch accepts a late timed-out result
  and violates result consistency; the Fixed branch classifies it as stale. Fixed TLC passed in the
  370-case smoke, while the Current configuration produced the intended counterexample.
- Current stage: added `ParslJoinProviderMonitoring`, extending the cross-layer join model with
  data staging readiness, provider loss/reprovisioning, and monitoring queue persistence. Its
  Current branch again exposes stale-result acceptance; the Fixed branch passed standalone TLC.
- Current stage: added `ParslJoinZMQRetry`, which models task/result envelopes through framing,
  send/receive, decode, corruption rejection, and `(task, attempt)` resolution. The Fixed branch
  passed standalone TLC and the Current branch produced the intended stale-result violation.
  The model now also tracks mutable Python-object versions and serialization snapshots, with a
  dispatch invariant that catches live-object substitution after serialization.
- Current stage: added `ParslJoinFileStaging`, a two-chunk content/checksum/source-version model
  that gates join execution on safe publication. The Current branch publishes corrupt bytes and
  violates readiness/content safety; the Fixed branch passed standalone TLC.
- Current stage: added `ParslJoinMonitoringDB`, connecting terminal join status to queued and
  persisted monitoring rows. The Current branch loses terminal status on a duplicate write; the
  Fixed branch treats duplicates idempotently and passed standalone TLC.
- Current stage: promoted eight concrete provider/executor runtime bridges into the foundational
  gate: Flux cancellation races, Globus Compute submit overlap, HTEX cancellation admission,
  Local PID admission, poller close/duplicate registration, and scale-in result shape.
- Current stage: promoted four monitoring DB runtime bridges into the foundational gate. The probes
  cover batch boundaries, permanent insert/update errors, deferred worker messages, and duplicate
  observations against the installed SQLite-backed DatabaseManager.
- Current stage: added `ParslJoinHeartbeatRetry`, connecting logical clock and heartbeat expiry to
  task timeout, manager loss, reprovisioning, and stale-result rejection. The Current branch
  accepts a late expired-attempt completion; the Fixed branch passed standalone TLC.
- Current stage: added `ParslAbstractFullSmoke.cfg`, a positive integrated run with four tasks,
  dependency/join edges, memoization, object graphs, file outputs, two executors, three workers,
  provider capacity, heartbeat/task deadlines, and monitoring enabled. It passed standalone TLC.
- Current stage: added `ParslProviderTaskScaleRetry`, a provider-capacity model for admission,
  scale-in cancellation, retry, result completion, and monitoring. The Current branch leaves a
  running task without capacity; the Fixed branch moves it to `retry_wait` and passed standalone TLC.
- Current stage: promoted five timeout/heartbeat runtime bridges into the foundational gate:
  HTEX initial probe timeout, time-limited file open, bash cleanup, Python timeout parameters,
  and timer close behavior.
- Current stage: promoted nine scheduler/provider runtime bridges into the foundational gate:
  AWS cancel, Azure status, Condor submit, Flux submission failure, Google Cloud status, Grid
  Engine batch status, LSF status, PBSPro status, and Slurm status batch.
- Current stage: promoted six file-transfer provider runtime bridges into the foundational gate:
  Globus Compute resource/submit/shutdown behavior, Globus stage-in/out dependency wiring,
  Globus terminal transfer failure, and rsync stage-in/out ordering.
- Current stage: promoted ten serialization/ZMQ/HTEX runtime bridges into the foundational gate:
  serializer fallback/cache behavior, CurveZMQ certificate validation, monitoring-router failure,
  ambiguous and duplicate HTEX messages, submit-counter races, manager drain, and worker watchdog
  result races.
- Current stage: promoted six executor/task-transport runtime bridges into the foundational gate:
  ThreadPoolExecutor lifecycle/resource validation, invalid thread counts, ParslPoolExecutor map
  timeout semantics, real serialized ZMQ task execution, and LocalProvider stale cancellation.
- Current stage: promoted `ParslJoinEndToEnd` into the foundational TLC gate. The model keeps
  logical inner Futures separate from physical retry attempts and checks ordered join observation,
  cancellation/failure aggregation, terminal outer state, and result-shape safety in one compact
  cross-layer state machine.
- Current stage: promoted the compact `ParslHeartbeatRetry` model into the foundational TLC gate.
  It provides the simple clock/heartbeat baseline: monotonic manager expiry, task timeout,
  bounded retry, and rejection of late results before the more detailed provider/join timing
  compositions.
- Current stage: promoted `ParslMonitoringWorkflowDuration` into the foundational TLC gate. This
  small database-contract model checks that workflow duration survives the close/finalization
  update instead of being silently ignored by a schema mismatch.
- Current stage: promoted `ParslMonitoringZMQRouterFailure` into the foundational TLC gate. The
  compact transport model now checks that an unrecoverable monitoring receive channel reaches a
  terminal state instead of retrying indefinitely until an unrelated external stop.
- Current stage: promoted `ParslFilePathResolution` into the foundational TLC gate. The model
  separates local `file:` URLs from staged remote paths and rejects remote reads without a
  site-local annotation before the higher-level transfer/publication models run.
- Current stage: promoted `ParslSerializationZMQBridge` into the foundational TLC gate. This
  compact bridge connects serializer tokens and attempt IDs to framing, route validation,
  duplicate/discard handling, worker dispatch, result decoding, and stale-result rejection.
- Current stage: promoted all three `ParslExecuteTask` configurations into the foundational TLC
  gate. The worker-side baseline now checks valid value return, user exception propagation, and
  malformed payload rejection before invocation.
- Current stage: promoted `ParslBashAppOutcome` into the foundational TLC gate. The executor-side
  model separates shell exit, stdout side effects, declared output validation, and Future terminal
  success/failure so output publication cannot turn a failed Bash task into success.
- Current stage: promoted `ParslPoolExecutorMap` into the foundational TLC gate. The map iterator
  baseline now checks eager submission, ordered result consumption, iterator timeout as a caller
  deadline, and preservation of already-submitted tasks after timeout.
- Current stage: promoted the compact `ParslTorqueSubmit` provider model into the foundational TLC
  gate. Its success, empty-output, and qsub-failure configurations now check that scheduler output
  creates one pending resource only for a usable job identifier, while the runtime probe exercises
  the installed `TorqueProvider.submit` implementation including its multi-line response behavior.
- Current stage: promoted `ParslTaskVineShutdown` into the foundational TLC gate. The collector
  shutdown path now checks that outstanding Futures are failed with manager-failure semantics before
  the collector exits; the focused runtime probe invokes the installed collector implementation.
- Current stage: promoted `ParslTaskVineResults` into the foundational TLC gate. The result path now
  separates valid payloads, task exceptions, corrupt/missing output, no-result reports, and manager
  failure while preserving Future terminal-state and outstanding-task invariants.
- Current stage: promoted `ParslWorkQueueResults` into the foundational TLC gate. The Work Queue
  collector baseline now covers valid result files, serialized app exceptions, corrupt output,
  collector failure cleanup, and terminal-state stability for multiple task records.
- Current stage: promoted the Fixed `ParslCallableRetryTransport` configuration into the foundational
  TLC gate. Each retry captures an immutable callable/object snapshot; the Current configuration is
  retained as a deliberate TLC counterexample for late old-attempt acceptance, while the Fixed gate
  rejects it using attempt correlation.
- Current stage: promoted the Fixed `ParslCallableClosureMemo` configuration into the foundational
  TLC gate. It distinguishes callable closure payload contents from memoization identity; the Current
  configuration remains a counterexample where two closure values collide on a name/module key.
- Current stage: promoted all three `ParslStageOutFuture` modes into the foundational TLC gate.
  Separate stage-out now gates DataFuture readiness on publication, while in-task and no-stage modes
  complete output readiness with the application; dependent admission remains blocked until ready.
- Current stage: promoted the three `ParslRsyncStage` paths into the foundational TLC gate. Stage-in
  runs before the application, stage-out runs after it, and either transfer failure prevents false
  success while preserving the expected application execution ordering.
- Current stage: promoted `ParslMonitoringDeferred` into the foundational TLC gate. Worker status
  messages received before their TASK_INFO/TRY rows are deferred and replayed only after the foreign
  key exists; duplicate first observations are explicitly bounded and status rows stay admissible.
- Current stage: promoted the Fixed and valid `ParslTimerIntervalValidation` configurations into the
  foundational TLC gate. Negative intervals are rejected by the Fixed branch instead of becoming a
  zero-delay timer; the Current branch remains a deliberate counterexample and runtime probe.
- Current stage: promoted the basic `ParslCommandClient` reply and timeout configurations into the
  foundational TLC gate. A successful REQ/REP completes normally, while a response timeout poisons
  the client and prevents reuse of a request socket with unknown state.
- Current stage: promoted both `ParslJoinNoneResult` configurations into the foundational TLC gate.
  Single-Future and list joins preserve `None` as a successful result, keep list positions intact,
  and release the join handle only after all selected inner Futures are observed.
- Current stage: promoted the Fixed `ParslJoinReturnEquality` configuration into the foundational
  TLC gate. Invalid join returns now take a terminal validation-failure path before user-defined
  equality can raise; the Current and truthy-equality variants remain documented counterexamples.
- Current stage: promoted the Fixed `ParslJoinSingleCancellation` configuration into the foundational
  TLC gate. A cancelled inner Future now becomes terminal outer join failure; the Current branch
  remains a counterexample where `CancelledError` escapes and leaves the outer join pending.
- Current stage: promoted `ParslPollerBadState` into the foundational TLC gate. Provider polling,
  failure-threshold handling, outstanding-task failure, and scale-out/scale-in suppression after a
  bad executor state are now checked in one bounded provider state machine.
- Current stage: promoted the Fixed `ParslApplyDispatchBoundary` configuration into the foundational
  TLC gate. Malformed four-frame apply messages are rejected at the serialization facade before worker
  invocation; the Current configuration remains a deliberate arity counterexample.
- Current stage: promoted the Fixed and valid `ParslPythonTimeoutParameter` configurations into the
  foundational TLC gate. Non-positive Python-app timeout values are rejected before wrapper execution;
  the Current configuration remains a deliberate immediate-timeout counterexample.
- Current stage: promoted the Fixed and success `ParslTimeLimitedOpenTimeout` configurations into the
  foundational TLC gate. A missing file now produces an explicit timeout before `open()` is attempted;
  the Current configuration remains a raw FileNotFoundError counterexample.
- Current stage: promoted the Fixed `ParslTimerCloseTimeout` configuration into the foundational TLC
  gate. A timed close reports an explicit closing/timeout outcome while the callback remains alive;
  the Current configuration remains a premature-closed counterexample.
- Current stage: promoted normal and abnormal `ParslMonitoringClose` configurations into the
  foundational TLC gate. Both paths set the kill/drain state, while workflow finalization is emitted
  only when a start message exists and no prior workflow-end was processed.
- Current stage: promoted the Fixed `ParslHtexWorkerDrainClock` configuration into the foundational
  TLC gate. Worker drain deadlines now use monotonic elapsed time; the Current configuration remains
  a wall-clock rollback counterexample that suppresses a due drain message.
- Current stage: promoted the Fixed `ParslResourceMonitorClock` configuration into the foundational
  TLC gate. Remote resource-monitor sampling now uses an elapsed monotonic schedule despite wall-clock
  rollback; the Current configuration remains a suppressed-due-sample counterexample.
- Current stage: promoted the Fixed and positive `ParslMonitoringBatch` configurations into the
  foundational TLC gate. A zero batching interval still consumes an available message in the Fixed
  path; the Current configuration remains the empty-batch counterexample.
- Current stage: promoted the Fixed `ParslMonitoringBatchClock` configuration into the foundational
  TLC gate. Batch deadlines now use monotonic elapsed time; the Current configuration remains a wall-
  clock rollback counterexample that drains past the intended deadline.
- Current stage: promoted `ParslProviderKinds` into the foundational TLC gate. The provider-neutral
  state machine now checks scheduler submit/status translation, missing-job semantics, cancellation,
  scale-in, provider failure/recovery, and CPU/task-per-node admission together.
- Current stage: promoted `ParslBlockProviderBadState` into the foundational TLC gate. An unrecoverable
  provider error records its cause, fails all pending tasks, preserves already terminal tasks, and
  rejects later submissions.
- Current stage: promoted `ParslJoinDuplicates` into the foundational TLC gate. Ordered duplicate Future
  references preserve list positions and repeated failure entries, while duplicate callbacks do not
  alter aggregate results or join-handle cleanup.
- Current stage: promoted `ParslJoinErrorRootCause` into the foundational TLC gate. Nested propagated
  join failures now retain the first leaf exception, annotate sibling dependencies, and preserve the
  root-cause path used by `JoinError`.
- Current stage: promoted five monitoring lifecycle runtime bridges into the foundational gate:
  close/finalization, starter construction failure, zero batching threshold, authenticated malformed
  UDP payloads, and workflow-duration schema behavior.
- Current stage: strengthened the HTEX worker poll-priority runtime bridge to sustain three
  consecutive iterations where task and result sockets are both readable. The installed source
  continues to service the task socket first and leaves the result socket unread in every iteration;
  this is now aligned with the `ParslHtexWorkerPollPriority` TLC counterexample rather than a
  one-shot scheduling artifact.
- Current stage: reran the complete bounded v0.1 regression after the source-aligned refinements:
  all 617 TLC smoke cases and all 415 Python runtime probe entries passed. Added
  `docs/v0.1-report.md` as the fixed-scope handoff with component mapping, invariant classes,
  Current/Fixed interpretation, limitations, and exact reproduction commands.
- Current stage: tightened `ParslTaskTransport` result acceptance. A physical result now needs
  both a valid result envelope and a valid payload bit before it can resolve the logical Future;
  `ResultDecodeSafety` is checked by TLC and the real serialized-task ZMQ probe still passes.
- Current stage: added `ParslResultDecodeRetryMonitoring`, a bounded cross-layer model combining
  result decode failure, physical retry generation, late old-attempt delivery, and monitoring
  status persistence. The Current case reaches a stale-success monitoring counterexample; the
  Fixed case rejects the old result, resets the monitoring high-water mark at retry, and passes
  100,001 simulated states.
- Current stage: added a real runtime bridge for that composition. The installed HTEX result worker
  reproduces the orphaned Future after corrupt decode, and the installed SQLite monitoring schema
  accepts an older `try_id` at a newer timestamp; the probe records this as a Current observation
  while the Fixed generation rule remains model-level.
- Current stage: reconciled the documentation counts with the executable manifests: 617 TLC
  `run_case` entries, 416 foundational Python probe entries, and 648 repository-wide unittest
  methods. The README, overview, coverage matrix, and validation report now distinguish these
  scopes instead of mixing historical counts.
- Current stage: added a real `join_app` retry/monitoring bridge. A decorated join with a real
  retried inner Python app reaches inner `try_id = 1`, while the SQLite STATUS table still accepts
  a later timestamp for `try_id = 0`; the probe is now part of the 417-entry runtime gate.
- Current stage: added `ParslHTTPInTaskTransferGate`. The model connects HTTP response status,
  streamed chunks, temporary/final publication, and wrapped-task admission. Its Current case
  reproduces a non-2xx response reaching user code; the Fixed case requires successful complete
  publication. The real wrapper probe passes, and the full gate now contains 618 TLC cases,
  418 runtime entries, and 654 discovered unittest methods.
- Current stage: added `ParslMonitoringRemoteLifecycle`. The model connects periodic resource
  sampling, wall-clock rollback, monotonic scheduling, termination, and the unconditional final
  resource message. The real monitor bridge confirms rollback does not drop the final message.
  The full gate now contains 619 TLC cases, 419 runtime entries, and 655 discovered unittest
  methods.
- Current stage: added `ParslHTTPInTaskAdmission`, a joint status/Content-Length/task-admission
  refinement. It reuses the existing BUG-172 and BUG-288 observations without creating a
  duplicate ledger entry: Current admits a non-success short response, while Fixed blocks user
  code until both checks pass. The full gate now contains 620 TLC cases, 420 runtime entries,
  and 656 discovered unittest methods.
- Current stage: added `ParslRemoteExceptionTransport`. It models a nested
  `RemoteExceptionWrapper` cause surviving serialization and becoming a terminal Future failure;
  the real HTEX result worker probe verifies the leaf cause after decoding. The full gate now
  contains 621 TLC cases, 421 runtime entries, and 657 discovered unittest methods.

### Verification convention

Each stage is checked with a Current TLC configuration, a Fixed TLC configuration, and a targeted
runtime probe against the installed Parsl source when the boundary is concrete. The full smoke
runner is a bounded regression gate; it is not an exhaustive proof of all Parsl implementation
states.

### Next audit direction

Continue source-aligned refinement of executor/provider details and `join_app` composition. Prefer
new cross-layer models that connect logical Futures, physical attempts, transport/staging events,
and monitoring records rather than duplicating an existing single-boundary model.

## Scope note

The repository preserves the implementation artifacts and project decisions. It does not claim to
archive the external chat transcript or control platform-level conversation retention.

For continuity, treat this file as the durable handoff point: after each meaningful stage, update
the latest commit, verification counts, completed work, and next audit direction before pushing.
