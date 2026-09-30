# Abstraction coverage matrix

This repository intentionally uses bounded abstractions. The table below records what is
currently modeled, which runtime probes corroborate it, and where the abstraction is still
coarse. A passing TLC run is evidence for the listed finite model, not a proof of all Parsl
implementations or every detail in the paper.

| Area | TLA+ coverage | Runtime evidence | Remaining coarse boundary |
| --- | --- | --- | --- |
| Core DFK lifecycle | ParslAbstract, ParslEndToEnd, ParslDataFlowCleanup, ParslDataFlowWaitSnapshot (including cleanup boundary), ParslTaskStatusFutureOrdering, ParslTaskStagingMonitoring, ParslDataReadyExecution, ParslProviderFailureRetry, ParslResultDecodeRetry, ParslRetryHandlerNegativeCost, ParslRetryHandlerNonNumericCost, ParslInputListMutation, ParslOutputListMutation, ParslDynamicTaskCreation, ParslDynamicTaskFanout, ParslDynamicTaskChain | DataFlow cleanup, wait-snapshot/late-task, task-status/Future ordering, stage-out/DataFuture/consumer/monitoring ordering, integrated data-readiness/version and execution model, provider/retry and result-decode runtime probes, negative/non-numeric retry-handler cost, input/output-list mutation probes, and bounded parent-to-child/two-level dynamic-DAG safety | Component internals remain bounded and symbolic |
| ZMQ and serialization | ParslSerializationShortFrameCount, ParslSerializationTruncatedLength, ParslApplyMessageArity, ParslWorkerPoolControlFrame, ParslZMQObjectSnapshot, ParslFunctionObjectTransport, ParslCallableRetryTransport, ParslZMQ, ParslSerializationWire, ParslSerializationZMQBridge, ParslTaskTransport, ParslTaskTransportCloseRace, ParslZMQSerializationEndToEnd, ParslZMQAckRetry, ParslMessageCorrelation, ParslMessageCorrelationThree, ParslSerializerHeaderConsistency, ParslSerializationBinaryPayload, ParslSerializationFallback, ParslSerializerRegistry, empty-registry handling, negative-length framing, CurveZMQ certificate-directory validation, malformed envelope framing, dynamic plugin cache, failed-plugin cache, PoolExecutor callable cache, HTEX `probe_addresses`, ResultsIncoming, TasksOutgoing, TasksOutgoing close race, HTEX task-message field/type/priority validation, manager identity boundary, malformed manager result frames, terminal-Future result handling, and callable/argument aliasing | test_zmq_serialization_runtime.py, test_function_object_transport_runtime.py, test_callable_retry_transport_runtime.py, test_serializer_header_consistency_runtime.py, task-transport, task-transport-close, short-frame count, truncated-length, apply-message arity, worker-pool control-frame, object snapshot, binary payload, negative-length, CurveZMQ certificate, probe-address, ResultsIncoming/TasksOutgoing, serializer registry collision, serializer fallback/cache, empty-registry, malformed-envelope, failed-plugin-cache, unhashable-callable, task-message/type/priority, manager-message, malformed-result, cancelled-Future result, serializer-frame-count, and callable-argument-alias probes | Bounded queues, ACK/retry counts, and symbolic bytes; object graphs and wire queues remain finite; no full distributed timing model |
| Python functions and object contents | ParslPython, ParslFunctionObjectContents, ParslFunctionObjectTransport, ParslCallableRetryTransport, ParslObjectSnapshotRetry, ParslSerializationSnapshot, ParslCallableClosureMemo, ParslMemoFunctionIdentity, ParslCallableMutationCache, ParslCallableDeserializeCache, ParslCallableSerializerCache, ParslCallableEqualCache, ParslCallableArgumentAlias, ParslPythonNestedAlias, ParslFileCleanCopy, ParslSerializationPluginError, ParslSerializationPluginFailureCache, and ParslPoolExecutorCallableCache | function-object content, closure transport snapshot, per-attempt closure snapshots, closure and argument snapshots, callable snapshot/retry, function-body identity, mutation/deserialization-cache, equality-collision/unhashable-callable, callable/argument/nested-field alias identity, File clean-copy, invalid-plugin, malformed-envelope, failed-plugin-cache, PoolExecutor callable cache, test_memo_closure_runtime.py, tools/cloudpickle_fixture.py | Object graphs are finite symbolic nodes rather than arbitrary Python heaps; callable and nested roots remain bounded |
| Files and transfer | ParslFileBytes, ParslFileTransferRetry, ParslDataManagerCache, ParslDataFutureTransfer, ParslDataFutureCancellationPropagation, ParslFilePathResolution, ParslDataManagerStageInOrdering, ParslDataManagerStageOutOrdering, ParslStagingProviderDispatch, ParslFTPPartialCleanup, ParslHTTPStatusValidation, ParslRsyncPartialCleanup, ParslZipPathValidation, ParslGlobusEndpointPath, ParslGlobusTokenFileAtomicity, ParslGlobusTransferTimeout, ParslFileCleanCopy, ParslMultiOutputVersionedStageOut, ParslThreeOutputVersionedStageOut, JobStatus output summaries, and staging-provider models | file, DataFuture/cancellation, version/publication ordering, stage-in cache invalidation, two-/three-output atomic publication, File path, clean-copy, output-summary, provider dispatch, input/output-list aliasing, FTP/Rsync partial-cleanup, HTTP status, Zip path-validation, Globus endpoint-path/token-file/active-timeout, bounded chunk/checksum validation through real Zip stage-out/stage-in, DataManager ordering, FTP/HTTP/Rsync/Zip/Globus probes | Chunk counts, poll budgets, cache entries, output counts, and content versions are bounded |
| Time, heartbeat, timeout | ParslTimedHeartbeat, ParslTimeoutMonitoring, ParslHeartbeatTimeoutPersistence, ParslHeartbeatClockJump, ParslHeartbeatClockRollback, ParslHeartbeatLateAck, ParslHeartbeatParameterValidation, ParslPythonTimeoutParameter, ParslPeriodicTimer, ParslTimerIntervalValidation, ParslTimeLimitedOpenTimeout, ParslTimerCloseTimeout, ParslTimerReentrantClose, ParslWorkerContactTimeout, ParslWorkerPoolControlFrame, provider polling clock rollback, CommandClient lock/deadline boundary | heartbeat/monitoring, strict HTEX heartbeat boundary and manager expiry, heartbeat-parameter, Python-timeout, deadline, command-timeout, lock-timeout, periodic-timer/interval/file-open/close-timeout, re-entrant Timer close, worker-contact, worker-pool control-frame, and provider-poll probes | Logical time replaces OS scheduling and network latency; thread scheduling remains bounded by runtime probes |
| Monitoring database | ParslMonitoringDelivery, ParslMonitoringEventStream, ParslFileTransferMonitoring, ParslMonitoringDB, ParslMonitoringStatusHistory, ParslMonitoringDBInsert, ParslMonitoringTaskRetry, ParslMonitoringBatchAtomicity, ParslMonitoringBatchThree, ParslMonitoringLastMessageRace, ParslMonitoringDeferredMultiplicity, ParslMonitoringShutdownDrain, ParslMonitoringShutdownRace, ParslMonitoringPersistentRetry, ParslMonitoringUpdatePersistentRetry, ParslMonitoringDBPermanentError, ParslMonitoringDBUpdatePermanentError, ParslMonitoringMalformedWorkerMessage, ParslMonitoringDispatchEnvelope, ParslMonitoringBatchClock, ParslMonitoringHubClose, ParslMonitoringCloseIdempotence, ParslMonitoringZMQRouterFailure, ParslFilesystemRadioAtomicity, HTEX monitoring-message boundary | monitoring/file-version ordering, multi-task producer/queue/database high-water ordering, three-event transaction rollback, append-only SQLite status history and timestamp ordering, DB insert/update retry and duplicate-idempotence, mixed-batch rollback, permanent-error loss, malformed worker/envelope, persistent insert/update lock watchdogs, batching clock rollback, batching, hub-close and DB-close idempotence, persistent ZMQ receive failure, atomicity, close, deferred-ordering and multiplicity, shutdown-drain/race, filesystem-radio atomicity, and HTEX payload probes | Database schema and transaction batches are reduced to finite records |
| Executors/providers | ParslThreadExecutorResourceSpec, ParslManagerLivenessPool, ParslBadStateTerminalFuture, ParslHtexAmbiguousResult, ParslHtexUnknownTaskResult, ParslHtexManagerLoss, ParslHtexExecutorResultFrameContinuation, ParslHtexWorkerTaskFrameContinuation, ParslHtexWorkerTaskBatchShape, ParslHtexResultQueue, ParslHtexDuplicateResult, ParslHtexDuplicateRegistration, ParslHtexSubmitCounterRace, ParslNegativeScaleIn, ParslPoolExecutorMap, ParslWorkQueueSubmit, ParslTaskVineSubmit, ParslFluxErrorCleanupCancellation, ParslPollerCloseScaleInRace, ParslPollerDuplicateExecutor, ParslAwsUnknownInstance, ParslAWSProviderCancel, ParslAwsSubmitEmptyResponse, ParslLocalUnknownJobStatus, ParslLocalProviderStatusScope, ParslLocalProviderExitStatus, ParslKubernetesCancelUnknownJob, ParslKubernetesPolling, ParslCondorMalformedStatusLine, ParslCondorStatusFailure, ParslGridEngineDuplicateStatus, ParslPBSProJobIdAlias, ParslPBSProMalformedJSON, ParslSlurmForeignJob, ParslSlurmMalformedLine, ParslGoogleCloudZoneSelection, ParslGoogleCloudCancel, ParslGoogleCloudStatus, ParslAzureCancel, ParslAzureProviderSubmit, ParslHtexManagerTaskAdmission, ParslKubernetesAdmission, ParslProvisioningAdmissionMonitoring, ParslProviderWorkerScaling, ParslBashAppOutcome, ParslScaleInRetryMonitoring plus lifecycle, HTEX task/manager/result handling, manager selection, manager drain, duplicate registration, concurrent task-ID allocation, negative scale-in validation, ResultsIncoming, TasksOutgoing, malformed result frames and batch continuation, optional monitoring-frame continuation, Grid Engine malformed-status and duplicate-status continuation, terminal-Future result handling, duplicate-result handling, CommandClient pre-send timeout, lock/deadline handling, and ignored `max_retries` audit, cancelled-result delivery, forced busy-block scale-in and idle-threshold protection, MPI resource derivation, unmapped-result handling, and backlog retry behavior, Bash timeout cleanup plus shell exit/output/Future gating, Work Queue submit/resource-category validation and cancelled-result delivery, TaskVine submit/cancelled-result delivery and submit ordering, WorkQueue/TaskVine shutdown, Flux submission/cancellation races and cleanup cancellation, provider status-empty handling and error cleanup, Azure status-bookkeeping consistency and partial-submit rollback, PBS Pro malformed JSON handling, Slurm foreign-job/malformed-line handling, Slurm strict-batch validation, Torque tasks-per-node validation and failed-command status handling, Globus Compute Future propagation and concurrent-submit configuration race, RadicalPilot failure payload, late callback handling, and bulk shutdown, TaskVine factory lifecycle, scale-out failure monitoring, JobStatus output read errors, unknown-manager isolation, ClusterProvider script generation, LocalProvider failed-launch script cleanup and stale cancellation handling, provider polling clock rollback, walltime parsing, LSF negative-resource validation and missing-job status handling, BlockProvider bad-state ordering/mutation, zero-capacity strategy admission, Kubernetes and Condor chunk-size/unknown-job status handling, ThreadPoolExecutor thread-count validation, HTEX `cores_per_worker` and address-probe-timeout propagation, zero-task LocalProvider launch validation, Thread, WorkQueue, Flux, TaskVine, LocalProvider, `ParslBlockProviderBadState`, scheduler-specific models, and the strategy policy | 431 local/fake-provider runtime tests, including LocalProvider exit-marker precedence and terminal caching, Bash app success/failure/output semantics, Azure partial-submit rollback, AWS stale cancellation/unknown-instance, LocalProvider stale-status/scope, Kubernetes stale-status/cancel, Condor malformed-line/status-failure, Grid Engine duplicate-status, PBS Pro malformed-JSON, Slurm foreign-job/malformed-line, Google Cloud cancellation/status probes, Azure missing-local cancel, strategy scaling probes, PoolExecutor map, poller close/scale-in, duplicate poller registration, ThreadPool resource-spec, HTEX manager-loss, duplicate registration, concurrent task-ID allocation, negative scale-in, HTEX unknown-task-result, ambiguous-result, malformed-batch-continuation, optional-monitoring-batch, Grid Engine status-batch, executor result-frame, worker-task-frame, worker-batch-shape, duplicate-result, staging-provider dispatch, and input/output-list aliasing probes | Not every backend implementation is modeled at identical depth |
| join_app | ParslJoinFull, ParslJoinCallableTransport, ParslJoinComplete, ParslJoinInternalExecutor, ParslJoinRetry, ParslJoinRetryDuplicates, ParslJoinRetryCancellation, ParslJoinDuplicateFailureAggregation, ParslJoinReturnShape, ParslNestedJoin, ParslNestedJoinFailure, ParslTripleNestedJoin, ParslJoinCallbackMultiplicity, failure aggregation, root-cause metadata, callback/cancellation/mutation/nested/memo-data models, and single-Future cancellation | 24 join runtime tests covering internal-executor routing, serialized callable transport, memoization, single/list/empty/None results, duplicate positions, retry, cancellation, return validation, callback races, mutation, two-/three-level nested joins, failure aggregation, and root-cause metadata | Python exception identity and arbitrary user object graphs remain abstract |

Recent refinements: `ParslHtexTaskIdType` and `ParslHtexTaskContextType` add decoded task-envelope
ID/context validation to the HTEX executor coverage. Their runtime probes confirm that malformed
IDs or non-mapping contexts currently escape `Interchange.process_task_incoming`; the fixed models
reject them before scheduler insertion.

The executor/provider runtime list also retains the PBS Pro job-ID alias and malformed-JSON
checks; the scaling model above is an additional symbolic admission layer rather than a replacement
for backend-specific probes. The provider-worker scaling bridge is corroborated by
`tests/test_provider_worker_scaling_runtime.py`.

Executor-selection coverage also includes `ParslExecutorSelection`, which isolates the empty-list
validation boundary before `random.choice`.

Memoization coverage also includes `ParslMemoIgnoreKey`, which isolates unknown
`ignore_for_cache` names before cache-key construction.

It also includes `ParslMemoIgnoreOutputs`, which checks idempotent handling of the special
`outputs` key when it appears in the ignore list.

The next refinements should select one row, read the relevant source path, and add a focused
model plus a runtime probe before expanding the state space.

The executor row now also includes `ParslThreadExecutorFutureLifecycle` and its runtime bridge,
which exercise queued-versus-running cancellation and shutdown waiting on a real thread pool.

Serialization coverage also includes `ParslApplyDispatchBoundary`, which links real framed
payloads to worker invocation arity and records the current late rejection boundary.

Clock/executor coverage also includes `ParslHtexShutdownTimeout`, which checks deadline-driven
interchange kill ordering before ZMQ pipe closure.

Join coverage also includes the end-to-end cancelled-inner-Future bridge for `ParslJoinCancellation`;
the current branch intentionally reproduces the non-terminal outer join state.

The list-valued cancellation path is likewise bridged end to end by
`test_join_list_cancellation_end_to_end_runtime.py` and `ParslJoinListCancellation`.

The executor/provider row also includes `ParslScaleInCancelShape` and its short-provider-cancel
runtime probe; the model isolates malformed cancellation cardinality from normal scale-in policy.

The `join_app` row also includes `ParslJoinReturnEquality` and its hostile-`__eq__` runtime probe;
the model isolates return-shape validation from ordinary Future aggregation.

The files/transfer row also includes `ParslHTTPConnectionCleanup` and its streaming-response
failure probe; response lifetime is modeled separately from partial destination publication.

The executor/provider row also includes `ParslProviderStatusShape` and its short-status runtime
probe; status-response cardinality is modeled separately from cancellation-response shape.

The ZMQ/time row also includes `ParslCommandDeadline` and its expired-deadline poll probe; the
model separates timeout arithmetic from command-socket poisoning.

The executor/provider coverage also includes `ParslBadStateTaskMutation` (BUG-088), which checks
that Future callbacks cannot abort executor-failure propagation by mutating the task registry.

The provider baseline also includes `ParslClusterStatusRequest`, which checks one backend poll and
ordered/duplicate projection of the public status response.

Heartbeat coverage also includes the rollback branch of `ParslHeartbeatClockRollback` (BUG-089),
which separates wall-clock reporting from monotonic expiry.

Monitoring coverage includes the corresponding batch-deadline rollback boundary
`ParslMonitoringBatchClock` (BUG-090).

Worker-side monitoring coverage also includes `ParslResourceMonitorClock` (BUG-162), which
separates periodic sampling deadlines from wall-clock timestamps.

Provider coverage also includes `ParslDuplicateJobId` (BUG-163), which checks that scale-out
reverse ownership remains one-to-one when a provider returns duplicate job IDs.

ZMQ executor coverage also includes `ParslResultsIncomingCloseRace` (BUG-091), modeling
post-close result polling as a quiescent boundary.

Join coverage also includes a concrete nested-join runtime probe for `ParslNestedJoin`, covering
ordered success and failure propagation through two join layers.

`ParslTripleNestedJoin` extends the state abstraction to three dependency levels and checks that
the second join cannot finalize before both the inner join and its independent leaf are terminal.

DataFuture coverage also includes the falsey-exception propagation boundary
`ParslDataFutureFalseyException` (BUG-092).

Radical-Pilot executor coverage also records the missing failure-payload boundary
`ParslRadicalPilotFailurePayload` (BUG-093).

Flux executor coverage also records the empty provider-status response boundary
`ParslFluxProviderStatusEmpty` (BUG-094).

Work Queue coverage also records the unreachable category-resource branch
`ParslWorkQueueResourceCategory` (BUG-095).

HTEX task admission coverage also records the non-numeric priority boundary
`ParslHtexTaskPriorityType` (BUG-096).

HTEX task admission coverage also records the non-mapping resource-specification boundary
`ParslHtexTaskResourceSpecType` (BUG-097).

HTEX task admission coverage also records malformed task-envelope handling
`ParslHtexTaskMessageMalformed` (BUG-098).

HTEX result-path coverage also records malformed result-frame isolation
`ParslHtexResultMessageMalformed` (BUG-099).

HTEX result-path coverage also records stale/unknown task-result handling
`ParslHtexUnknownTaskResult` (BUG-100).

HTEX result-path coverage also records ambiguous frames carrying both result and exception
payloads (`ParslHtexAmbiguousResult`, BUG-101).

Python serialization coverage also records the unhashable-callable cache-key boundary
(`ParslCallableSerializerCache`, BUG-102).

Python serialization coverage also records mutable callable-instance aliasing on repeated decode
(`ParslCallableDeserializeCache`, BUG-103).

Python serialization coverage also records failed dynamic-plugin cache retention
(`ParslSerializationPluginFailureCache`, BUG-104).

File-transfer coverage also records FTP partial-destination publication on stream failure
(`ParslFTPPartialCleanup`, BUG-105).

Monitoring coverage also records malformed worker-message isolation
(`ParslMonitoringMalformedWorkerMessage`, BUG-106).

Clock/heartbeat coverage also records invalid HTEX heartbeat-parameter admission
(`ParslHeartbeatParameterValidation`, BUG-107).

Clock/timeout coverage also records negative Python-app timeout admission
(`ParslPythonTimeoutParameter`, BUG-108).

ZMQ command coverage also records the ignored `CommandClient.max_retries` contract
(`ParslCommandClientMaxRetries`, BUG-109).

ZMQ command coverage also records lock acquisition outside the command deadline
(`ParslCommandClientLockTimeout`, BUG-110).

Condor provider coverage also records nonpositive scheduler command chunk-size admission
(`ParslCondorChunkSize`, BUG-111).

Local provider coverage also records zero `tasks_per_node` admission
(`ParslLocalTasksPerNode`, BUG-112).

HTEX executor coverage also records zero `cores_per_worker` capacity derivation
(`ParslHtexCoresPerWorker`, BUG-113).

HTEX executor coverage also records explicit zero address-probe-timeout propagation
(`ParslHtexAddressProbeTimeout`, BUG-114).

LSF provider coverage also records negative core-capacity derivation
(`ParslLSFResourceValidation`, BUG-115).

Local provider coverage also records stale cancellation-id handling
(`ParslLocalProviderCancelUnknown`, BUG-116).

Slurm provider coverage also records strict-batch fallback compatibility
(`ParslSlurmBatchStrict`, BUG-117).

Provider timing coverage also records wall-clock rollback suppression in `poll_facade`
(`ParslProviderPollClockRollback`, BUG-118).

Torque provider coverage also records negative `tasks_per_node` admission
(`ParslTorqueTasksPerNode`, BUG-119).

Provider walltime coverage also records positive sub-minute truncation
(`ParslWalltimeParsing`, BUG-120).

Local provider coverage also records failed-launch script cleanup
(`ParslLocalProviderSubmitCleanup`, BUG-121).

Poller lifecycle coverage also records close/scale-in overlap
(`ParslPollerCloseScaleInRace`, BUG-122).

Poller lifecycle coverage also records duplicate executor registration
(`ParslPollerDuplicateExecutor`, BUG-123).

Monitoring/ZMQ coverage also records unbounded persistent receive-failure retry
(`ParslMonitoringZMQRouterFailure`, BUG-124).

HTEX manager lifecycle coverage also records stale drained-manager isolation
(`ParslHtexManagerDrain`, BUG-125).

Kubernetes admission coverage also records the Pending-pod/Running-job mismatch
(`ParslKubernetesAdmission`, BUG-126).

Serialization coverage now includes an explicit runtime check that `pack_apply_message` emits
three ordered serializer buffers (`ParslSerializationWire` and
`test_zmq_serialization_runtime.py::test_apply_message_has_three_length_prefixed_serializer_buffers`).

Thread executor coverage also records delayed zero-thread-count validation
(`ParslThreadExecutorThreadCount`, BUG-127).

Timer coverage also records close returning before callback quiescence
(`ParslTimerCloseTimeout`, BUG-128).

Monitoring database coverage also records TASK-row bookkeeping before insert success
(`ParslMonitoringTaskInsertBookkeeping`, BUG-129).

Slurm provider coverage also records malformed status-line isolation
(`ParslSlurmMalformedLine`, BUG-130).

HTEX executor coverage now includes manager selector/dispatch eligibility separation
(`ParslHtexManagerEligibility` and `test_htex_manager_eligibility_runtime.py`).

Join coverage now documents the already-completed-inner-Future callback registration race
(`ParslJoinImmediateCallback` and `test_join_runtime.py::test_already_completed_inner_future_callback`).

Thread executor coverage also records non-mapping resource-specification validation
(`ParslThreadExecutorResourceSpec`, BUG-131).

Executor timeout coverage also records process cleanup after `execute_wait` timeout
(`ParslExecuteWaitTimeout`, BUG-132).

Bash executor coverage also records process cleanup after app walltime timeout
(`ParslBashTimeoutCleanup`, BUG-133).

Clock/file-wait coverage also records explicit timeout handling before `open()`
(`ParslTimeLimitedOpenTimeout`, BUG-134).

Clock/heartbeat coverage also records worker contact expiry suppressed by wall-clock rollback
(`ParslWorkerContactClockRollback`, BUG-137).

Staging coverage also records loss of an existing good destination during failed HTTP replacement
(`ParslHTTPExistingDestination`, BUG-138).

Radical-Pilot executor coverage also records late terminal callbacks after cancellation
(`ParslRadicalPilotLateCallback`, BUG-135).

Radical-Pilot executor coverage also records queued-task loss during bulk shutdown
(`ParslRadicalPilotBulkShutdown`, BUG-136), and ignores callbacks for already-removed task IDs
(`ParslRadicalPilotUnknownCallback`, BUG-144).

HTEX executor coverage now separates worker watchdog restart from logical task failure
(`ParslHtexWorkerWatchdog`).

HTEX executor coverage also models the watchdog/result publication race
(`ParslHtexWatchdogResultRace`, BUG-139).

Monitoring database coverage also models TRY-row bookkeeping after failed insertion
(`ParslMonitoringTryInsertBookkeeping`, BUG-140).

Monitoring database coverage also models WORKFLOW-row bookkeeping after failed insertion
(`ParslMonitoringWorkflowInsertBookkeeping`, BUG-141).

Monitoring database coverage also models WORKFLOW end-update bookkeeping after failure
(`ParslMonitoringWorkflowEndBookkeeping`, BUG-142).

Join coverage now includes the combined logical-Future/physical-attempt state machine
(`ParslJoinEndToEnd`).

AWS provider coverage also records status-list cardinality when EC2 omits a requested instance
(`ParslAwsStatusMissingResult`, BUG-143).

Work Queue and TaskVine coverage also records duplicate/late collector reports that crash the
result thread (`ParslWorkQueueDuplicateReport` and `ParslTaskVineDuplicateReport`, BUG-145/146).

Local provider coverage also records a missing live-job exit-code file during polling
(`ParslLocalExitFileMissing`, BUG-147).

ZMQ executor coverage also includes `ParslTasksOutgoingCloseRace` (BUG-165), which checks that
task submission cannot reach a terminated DEALER socket.

HTEX admission coverage now combines registration version mismatch with heartbeat expiry in
`ParslHtexHeartbeatVersion`; the fixed model checks fatal-result ordering and rejects submissions
during the closing window.

Provider coverage also includes `ParslProviderProvisioningLifecycle`, combining provisioning
retry, stale generation polling, dispatch admission, and scale-in safety.

Provider coverage also includes `ParslProviderMultiBlockOwnership` and
`ParslProviderThreeBlockOwnership`, adding two- and three-block ownership
and task-to-block scale-in safety.

Monitoring coverage now combines batch rollback with per-task version high-water handling in
`ParslMonitoringVersionedBatch`.

Python object coverage also combines callable/argument aliasing with mutation-aware retry epochs
in `ParslCallableAliasRetry`.

Staging coverage also combines multi-output publication, source-version changes, per-output
retry, and atomic consumer release in `ParslMultiOutputVersionedStageOut`.

Join coverage also combines nested joins, leaf retry, and stale leaf-result rejection in
`ParslNestedJoinRetry`.

Core DFK coverage also combines timeout-driven retry with late result rejection in
`ParslTimeoutRetryStaleResult`.

Time coverage also includes `ParslConcurrentTimeouts` and `ParslThreeConcurrentTimeouts`,
modeling independent timeout clocks and cross-task late-result isolation for two and three
concurrent logical tasks.

Executor capacity coverage also includes `ParslHtexWorkerCapacity`, which mirrors the HTEX
constructor's CPU-, memory-, maximum-worker-, and accelerator-limited worker calculation and is
backed by `tests/test_htex_worker_capacity_runtime.py`.
