# Abstraction coverage matrix

The ZMQ/serialization coverage also includes `ParslHtexResultForwarding`, which models manager
task ownership across a failed `results_outgoing.send_multipart` call (BUG-225).

The monitoring coverage also includes `ParslMonitoringLifecycleBookkeeping`, which composes
successful/failed TASK, TRY, and WORKFLOW writes with finalization markers.

The file-transfer coverage also includes `ParslDataManagerStageOutReturn`, which distinguishes a
`None` stage-out return (the output follows the application Future) from an independent transfer
Future and checks output publication ordering with a real `DataManager` probe.

The heartbeat coverage also has a runtime bridge for `ParslHeartbeatLateAck`: a heartbeat-shaped
message from an expired manager is ignored by the real interchange path rather than resurrecting
the manager.

The dataflow coverage also includes `ParslAppFutureOutputStreams`, which models and tests the
`AppFuture.stdout`/`stderr` distinction between raw task-record values and installed stage-out
`DataFuture` overrides; tuple values remain an explicitly coarse boundary.

The `join_app` coverage also includes `ParslJoinBodyRetry`, which separates outer join-body retry
attempts from installation and completion of the inner Future join.

Provider coverage also includes `ParslLocalCancelFailure` (BUG-226), which checks that a failed
local kill command cannot be reported as successful cancellation. `ParslAzureCancelBookkeeping`
(BUG-227) checks that confirmed Azure deletion clears both the instance list and the resource map.
`ParslCondorStatusUnknown` (BUG-228) checks that a stale requested Condor ID is projected as
UNKNOWN rather than aborting the status call with a local-map `KeyError`.

Monitoring coverage also includes `ParslMonitoringZMQTupleShape`, which checks malformed-versus-
valid tuple admission in the real ZMQ monitoring router before queue/database delivery.

It also includes a direct runtime bridge for `ParslFutureWaitTimeout`, distinguishing caller wait
timeouts from task cancellation or task-level timeout failure.

This repository intentionally uses bounded abstractions. The table below records what is
currently modeled, which runtime probes corroborate it, and where the abstraction is still
coarse. A passing TLC run is evidence for the listed finite model, not a proof of all Parsl
implementations or every detail in the paper.

| Area | TLA+ coverage | Runtime evidence | Remaining coarse boundary |
| --- | --- | --- | --- |
| Core DFK lifecycle | ParslAbstract, ParslEndToEnd, ParslDataFlowCleanup, ParslDataFlowWaitSnapshot (including cleanup boundary), ParslTaskStatusFutureOrdering, ParslTaskStagingMonitoring, ParslDataReadyExecution, ParslDependencyFailurePropagation, ParslDataTransferDependencyFailure, ParslProviderFailureRetry, ParslResultDecodeRetry, ParslSerializedResultFile, ParslRetryHandlerNegativeCost, ParslRetryHandlerNonNumericCost, ParslMemoCheckpointResultFailure, ParslInputListMutation, ParslOutputListMutation, ParslDynamicTaskCreation, ParslDynamicTaskFanout, ParslDynamicTaskChain | DataFlow cleanup, wait-snapshot/late-task, task-status/Future ordering, stage-out/DataFuture/consumer/monitoring ordering, dependency blocking and DependencyError propagation, stage-out failure propagation across DataFuture into consumer admission, serialized result-file publication, integrated data-readiness/version and execution model, provider/retry and result-decode runtime probes, negative/non-numeric retry-handler cost, task-exit checkpoint serialization failure and terminal-Future handling, input/output-list mutation probes, and bounded parent-to-child/two-level dynamic-DAG safety | Component internals remain bounded and symbolic |
| ZMQ and serialization | ParslSerializationShortFrameCount, ParslSerializationTruncatedLength, ParslApplyMessageArity, ParslWorkerPoolControlFrame, ParslZMQObjectSnapshot, ParslFunctionObjectTransport, ParslCallableRetryTransport, ParslZMQ, ParslSerializationWire, ParslSerializationZMQBridge, ParslTaskTransport, ParslTaskTransportCloseRace, ParslZMQSerializationEndToEnd (including `ParslZMQSerializationEndToEndSmoke`), ParslZMQAckRetry, ParslMessageCorrelation, ParslMessageCorrelationThree, ParslSerializerHeaderConsistency, ParslSerializationBinaryPayload, ParslSerializationFallback, ParslSerializerRegistry, empty-registry handling, negative-length framing, CurveZMQ certificate-directory validation, malformed envelope framing, dynamic plugin cache, failed-plugin cache, PoolExecutor callable cache, HTEX `probe_addresses`, ResultsIncoming, TasksOutgoing, TasksOutgoing close race, HTEX registration state poisoning, HTEX task-message field/type/priority validation, manager identity boundary, malformed manager result frames, terminal-Future result handling, payload-integrity rejection, and callable/argument aliasing | test_zmq_serialization_runtime.py, test_function_object_transport_runtime.py, test_callable_retry_transport_runtime.py, test_serializer_header_consistency_runtime.py, four-task correlation multipart probe, task-transport, task-transport-close, short-frame count, truncated-length, apply-message arity, worker-pool control-frame, object snapshot, binary payload, negative-length, CurveZMQ certificate, probe-address, ResultsIncoming/TasksOutgoing, serializer registry collision, serializer fallback/cache, empty-registry, malformed-envelope, failed-plugin-cache, unhashable-callable, task-message/type/priority, manager-registration/state-poisoning, malformed-result, cancelled-Future result, serializer-frame-count, payload-integrity, and callable-argument-alias probes | Bounded queues, ACK/retry counts, and symbolic bytes; object graphs and wire queues remain finite; smoke configuration gives a fast complete route/correlation check |
| Python functions and object contents | ParslPython (including `ParslPythonSmoke`), ParslFunctionObjectContents, ParslFunctionObjectTransport, ParslCallableRetryTransport, ParslObjectSnapshotRetry, ParslSerializationSnapshot, ParslCallableClosureMemo, ParslMemoFunctionIdentity, ParslCallableMutationCache, ParslCallableDeserializeCache, ParslCallableSerializerCache, ParslCallableEqualCache, ParslCallableArgumentAlias, ParslPythonNestedAlias, ParslFileCleanCopy, ParslSerializationPluginError, ParslSerializationPluginFailureCache, and ParslPoolExecutorCallableCache | function-object content, closure transport snapshot, per-attempt closure snapshots, closure and argument snapshots, callable snapshot/retry, function-body identity, mutation/deserialization-cache, equality-collision/unhashable-callable, callable/argument/nested-field alias identity, File clean-copy, invalid-plugin, malformed-envelope, failed-plugin-cache, PoolExecutor callable cache, test_memo_closure_runtime.py, tools/cloudpickle_fixture.py | Object graphs are finite symbolic nodes rather than arbitrary Python heaps; callable and nested roots remain bounded; smoke configuration gives a fast complete graph check |
| Files and transfer | ParslFileBytes (including `ParslFileBytesSmoke`), ParslFileTransferRetry, ParslDataManagerCache, ParslDataFutureTransfer, ParslDataFutureCancellationPropagation, ParslFilePathResolution, ParslDataManagerStageInOrdering, ParslDataManagerStageOutOrdering, ParslStagingProviderDispatch, ParslFTPPartialCleanup, ParslHTTPContentLength, ParslHTTPStatusValidation, ParslHTTPSeparateTaskCleanup, ParslRsyncPartialCleanup, ParslZipPathValidation, ParslZipMemberSelection, ParslZipPathFirstMatch, ParslGlobusEndpointPath, ParslGlobusTokenFileAtomicity, ParslGlobusTransferTimeout, ParslFileCleanCopy, ParslMultiOutputVersionedStageOut, ParslThreeOutputVersionedStageOut, JobStatus output summaries, and staging-provider models | file, DataFuture/cancellation, version/publication ordering, stage-in cache invalidation, two-/three-output atomic publication, File path, clean-copy, output-summary, provider dispatch, input/output-list aliasing, FTP/Rsync partial-cleanup, HTTP content-length/status/status-path cleanup, Zip path-validation/member-selection/path-boundary, Globus endpoint-path/token-file/active-timeout, bounded chunk/checksum validation through real Zip stage-out/stage-in, DataManager ordering, FTP/HTTP/Rsync/Zip/Globus probes | Chunk counts, poll budgets, cache entries, output counts, member/separator counts, response-path states, and content versions are bounded; the smoke configuration gives a fast complete TLC run |
| Time, heartbeat, timeout | ParslTimedHeartbeat, ParslTimeoutMonitoring, ParslHeartbeatTimeoutPersistence, ParslHeartbeatClockJump, ParslHeartbeatClockRollback, ParslHeartbeatLateAck, ParslHeartbeatParameterValidation, ParslPythonTimeoutParameter, ParslPeriodicTimer, ParslTimerIntervalValidation, ParslTimeLimitedOpenTimeout, ParslTimerCloseTimeout, ParslTimerReentrantClose, ParslWorkerContactTimeout, ParslWorkerPoolControlFrame, provider polling clock rollback, CommandClient lock/deadline boundary | heartbeat/monitoring, strict HTEX heartbeat boundary and manager expiry, heartbeat-parameter, Python-timeout, deadline, command-timeout, lock-timeout, periodic-timer/interval/file-open/close-timeout, re-entrant Timer close, worker-contact, worker-pool control-frame, and provider-poll probes | Logical time replaces OS scheduling and network latency; thread scheduling remains bounded by runtime probes |
| Monitoring database | ParslMonitoringDelivery, ParslMonitoringEventStream, ParslFileTransferMonitoring, ParslMonitoringDB (including `ParslMonitoringDBSmoke`), ParslMonitoringStatusHistory, ParslMonitoringDBInsert, ParslMonitoringTaskRetry, ParslMonitoringBatchAtomicity, ParslMonitoringBatchThree, ParslMonitoringLastMessageRace, ParslMonitoringDeferredMultiplicity, ParslMonitoringShutdownDrain, ParslMonitoringShutdownRace, ParslMonitoringPersistentRetry, ParslMonitoringUpdatePersistentRetry, ParslMonitoringDBPermanentError, ParslMonitoringDBUpdatePermanentError, ParslMonitoringMalformedWorkerMessage, ParslMonitoringDispatchEnvelope, ParslMonitoringBatchClock, ParslMonitoringZMQBatchClock, ParslMonitoringHubClose, ParslMonitoringCloseIdempotence, ParslMonitoringZMQRouterFailure, ParslMonitoringUDPPickleIsolation, ParslMonitoringWorkerStatusAtomicity, ParslFilesystemRadioAtomicity, HTEX monitoring-message boundary | monitoring/file-version ordering, multi-task producer/queue/database high-water ordering, three-event transaction rollback, append-only SQLite status history and timestamp ordering, DB insert/update retry and duplicate-idempotence, mixed-batch rollback, permanent-error loss, malformed worker/envelope, persistent insert/update lock watchdogs, batching and ZMQ receive-batch clock rollback, batching, hub-close and DB-close idempotence, persistent ZMQ receive failure, authenticated malformed-UDP pickle isolation, cross-table STATUS/TRY atomicity, shutdown-drain/race, filesystem-radio atomicity, and HTEX payload probes | Database schema and transaction batches are reduced to finite records; smoke configuration gives a fast complete stream check |
| Executors/providers | ParslThreadExecutorResourceSpec, ParslManagerLivenessPool, ParslBadStateTerminalFuture, ParslHtexAmbiguousResult, ParslHtexUnknownTaskResult, ParslHtexManagerLoss, ParslHtexExecutorResultFrameContinuation, ParslHtexWorkerTaskFrameContinuation, ParslHtexWorkerTaskBatchShape, ParslHtexResultQueue, ParslHtexCancelledResult, ParslHtexCancelledFailureResult, ParslHtexCancellationAdmission, ParslHtexDuplicateResult, ParslHtexDuplicateRegistration, ParslHtexSubmitCounterRace, ParslMPINonPositiveResources, ParslLocalSubmitPidShape, ParslNegativeScaleIn, ParslPoolExecutorMap, ParslWorkQueueSubmit, ParslWorkQueueStartTimeoutCleanup, ParslTaskVineSubmit, ParslTaskVineStartFailureCleanup, ParslFluxErrorCleanupCancellation, ParslFluxLateFailureCancelledFuture, ParslFluxCancelRunningRace, ParslScaleInResultShape, ParslHtexRegistrationBlockId, ParslPollerCloseScaleInRace, ParslPollerDuplicateExecutor, ParslAwsUnknownInstance, ParslAWSProviderCancel, ParslAwsCancelDuplicates, ParslAwsSubmitEmptyResponse, ParslLocalUnknownJobStatus, ParslLocalProviderStatusScope, ParslLocalProviderExitStatus, ParslKubernetesCancelUnknownJob, ParslKubernetesPolling, ParslKubernetesEmptyPhase, ParslCondorEmptySubmit, ParslCondorMalformedStatusLine, ParslCondorStatusFailure, ParslGridEngineDuplicateStatus, ParslPBSProJobIdAlias, ParslPBSProMalformedJSON, ParslSlurmForeignJob, ParslSlurmMalformedLine, ParslGoogleCloudZoneSelection, ParslGoogleCloudZoneResponseShape, ParslGoogleCloudCancel, ParslGoogleCloudStatus, ParslAzureCancel, ParslAzureProviderSubmit, ParslHtexManagerTaskAdmission, ParslKubernetesAdmission, ParslProvisioningAdmissionMonitoring, ParslProviderWorkerScaling, ParslBashAppOutcome, ParslScaleInRetryMonitoring plus lifecycle, HTEX task/manager/result handling, manager selection, manager drain, duplicate registration, concurrent task-ID allocation, negative scale-in validation, ResultsIncoming, TasksOutgoing, malformed result frames and batch continuation, optional monitoring-frame continuation, Grid Engine malformed-status and duplicate-status continuation, terminal-Future result handling, duplicate-result handling, CommandClient pre-send timeout, lock/deadline handling, and ignored `max_retries` audit, cancelled-result delivery, forced busy-block scale-in and idle-threshold protection, MPI resource derivation, unmapped-result handling, and backlog retry behavior, Bash timeout cleanup plus shell exit/output/Future gating, Work Queue submit/resource-category validation and cancelled-result delivery, TaskVine submit/cancelled-result delivery and submit ordering, WorkQueue/TaskVine shutdown, Flux submission/cancellation races and cleanup cancellation, provider status-empty handling and error cleanup, Azure status-bookkeeping consistency and partial-submit rollback, PBS Pro malformed JSON handling, Slurm foreign-job/malformed-line handling, Slurm strict-batch validation, Torque tasks-per-node validation and failed-command status handling, Globus Compute Future propagation, shutdown cleanup, and concurrent-submit configuration race, RadicalPilot failure payload, late callback handling, and bulk shutdown, unknown-callback handling, and failure-fanout mutation safety, TaskVine factory lifecycle, scale-out failure monitoring, JobStatus output reads, unknown-manager isolation, ClusterProvider script generation, LocalProvider failed-launch script cleanup and stale cancellation handling, provider polling clock rollback, walltime parsing, LSF negative-resource validation and missing-job status handling, BlockProvider bad-state ordering/mutation, zero-capacity strategy admission, Kubernetes and Condor chunk-size/unknown-job status handling, ThreadPoolExecutor thread-count validation, HTEX `cores_per_worker` and address-probe-timeout propagation, zero-task LocalProvider launch validation, Thread, WorkQueue, Flux, TaskVine, LocalProvider, `ParslBlockProviderBadState`, scheduler-specific models, and the strategy policy | 440 local/fake-provider runtime tests, including LocalProvider malformed-PID admission, MPI non-positive resource admission, HTEX cancellation-admission and cancelled-result delivery, Condor empty-submit, Globus Compute shutdown cleanup, Work Queue startup-timeout cleanup, TaskVine startup-failure cleanup, and ZMQ monitoring batch-clock probes, plus the previously listed provider, executor, and lifecycle probes | Not every backend implementation is modeled at identical depth |
| join_app | ParslJoinFull, ParslJoinCallableTransport, ParslJoinComplete, ParslJoinInternalExecutor, ParslJoinRetry, ParslJoinRetryDuplicates, ParslJoinRetryCancellation, ParslJoinDuplicateFailureAggregation, ParslJoinReturnShape, ParslNestedJoin, ParslNestedJoinFailure, ParslTripleNestedJoin, ParslJoinCallbackMultiplicity, outer-cancellation, failure aggregation, root-cause metadata, callback/cancellation/mutation/nested/memo-data models, and single-Future cancellation | 26 join runtime tests covering internal-executor routing, serialized callable transport, memoization, single/list/empty/None results, duplicate positions, retry, nested retry, outer/inner cancellation, return validation, callback races, mutation, two-/three-level nested joins, failure aggregation, and root-cause metadata | Python exception identity and arbitrary user object graphs remain abstract |

The compact `ParslHeartbeatRetry` model is now in the foundational TLC gate. It isolates
monotonic heartbeat expiry, task timeout/retry, and stale late-result rejection before the larger
provider and join timing compositions.

`ParslMonitoringWorkflowDuration` is also in the foundational gate, connecting the computed
workflow-finalization duration to an explicit persisted database field.

`ParslMonitoringZMQRouterFailure` is also in the foundational gate, isolating terminal handling
of a permanently broken monitoring receive channel before database delivery can proceed.

`ParslFilePathResolution` is now in the foundational gate, checking the lower-level `File.filepath`
contract that local URLs resolve directly while remote URLs require a staged local path.

`ParslSerializationZMQBridge` is now in the foundational gate, providing the small executable
serializer-token/frame/route/correlation baseline used by the larger ZMQ retry models.

The three `ParslExecuteTask` configurations are now in the foundational gate, covering worker
decode, callable invocation, value/exception result publication, and malformed-message rejection.

`ParslBashAppOutcome` is now in the foundational gate, checking nonzero shell exits, output-file
validation, stdout side effects, and terminal Future resolution.

`ParslPoolExecutorMap` is now in the foundational gate, checking eager submission, ordered map
yielding, timeout-deadline behavior, and non-cancellation of already-submitted tasks.

Recent refinements: `ParslPipelineTimed` adds a compact DAG/physical-attempt/clock/monitoring
composition, `ParslProviderExecutorTimed` adds provider re-provisioning, manager heartbeat,
worker capacity, and bounded provider retry, and `ParslProviderExecutorTimedMonitoring` composes
that lifecycle with terminal monitoring persistence, provisioning-generation stale-poll checks, and
worker scale-in/scale-out admission.
`ParslZMQCallableRetry` now combines callable/object snapshots with task/result wire retries.
`ParslJoinFull` now includes the explicit serialized
attempt phase and current/fixed stale-result correlation after a physical retry. The three join
retry runtime probes (`test_join_retry_runtime.py`, `test_join_retry_duplicates_runtime.py`, and
`test_nested_join_retry_runtime.py`) all pass against the current Parsl source.

`ParslHtexTaskIdType` and `ParslHtexTaskContextType` add decoded task-envelope
ID/context validation to the HTEX executor coverage. Their runtime probes confirm that malformed
IDs or non-mapping contexts currently escape `Interchange.process_task_incoming`; the fixed models
reject them before scheduler insertion.

The executor/provider runtime list also retains the PBS Pro job-ID alias and malformed-JSON
checks; the scaling model above is an additional symbolic admission layer rather than a replacement
for backend-specific probes. The provider-worker scaling bridge is corroborated by
`tests/test_provider_worker_scaling_runtime.py`.

Globus Compute shutdown coverage now includes `ParslGlobusComputeShutdownCleanup`: SDK shutdown
failure must not skip result-watcher cleanup. Work Queue startup coverage also includes
`ParslWorkQueueStartTimeoutCleanup`, which stops components when the port announcement times out.
The runtime bridges use deterministic process/thread doubles, and the executor/provider probe
inventory is now 439 tests.

Google Cloud provider admission also includes `ParslGoogleCloudZoneResponseShape`, which
isolates the missing-`items` response boundary in `get_zone` and is backed by the zone-selection
runtime probe.

Monitoring startup coverage also includes `ParslMonitoringStarterConstructionFailure`, which
ensures a `DatabaseManager` constructor exception is not masked by cleanup of an unbound manager.

Kubernetes polling also includes `ParslKubernetesEmptyPhase`, which isolates a successful pod
response with a missing phase field and is backed by the Kubernetes polling runtime probe.

Slurm provider coverage also includes `ParslSlurmTasksPerNode`, which checks zero
`tasks_per_node` admission before the `cores_per_node` division and is backed by
`tests/test_slurm_tasks_per_node_runtime.py`.
`ParslSlurmCancelBatch` additionally models successful-prefix preservation when a cancellation
batch contains a stale local ID.

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

It also includes `ParslRsyncQuoting` (BUG-263), which models shell argument splitting when an
RSync source or destination path contains spaces. The current branch violates
`PathQuotingSafety`; the fixed branch uses a safely quoted command boundary, with runtime evidence
from `tests/test_rsync_quoting_runtime.py`.

The executor/provider row also includes `ParslProviderStatusShape` and its short-status runtime
probe; status-response cardinality is modeled separately from cancellation-response shape.

The provider row also includes `ParslAzureStatusShape` (BUG-176), which checks that a missing Azure
instance-view object cannot abort status polling.

It now also includes `ParslAzureStatusRemoteFailure` (BUG-211), which checks that a remote VM
lookup failure is isolated instead of aborting status results for unrelated requested jobs.

The provider row also includes `ParslLocalPidAdmission` (BUG-212), which checks that launcher
output cannot publish a zero/negative process ID as a live managed resource.

The executor row also includes `ParslHtexShutdownReap` (BUG-213), which checks that a forced
interchange kill is reaped before shutdown closes its dependent channels.

The serialization/ZMQ row also includes `ParslCommandSendFailure` (BUG-214), which checks that
failed command sends poison the REQ client instead of allowing unsafe reuse.

The provider row also includes `ParslPbsproSubmitShape` (BUG-215), which checks that a successful
PBS Pro submission publishes one validated job resource rather than every stdout line.

It also includes `ParslCondorSubmitWhitespace` (BUG-177), which checks scheduler whitespace
normalization before cluster/process ID expansion.

The join row also includes `ParslJoinImmediateCancellation` (BUG-178), which checks terminal
failure propagation when cancellation callbacks run synchronously during registration.

The provider row also includes `ParslGoogleCloudSubmitState` (BUG-179), which checks tolerant
state translation during instance creation.

The same row now includes `ParslClusterStatusUnknown` (BUG-170), which covers the shared
`ClusterProvider.status` projection when a requested local job ID has gone stale.

It also includes `ParslCondorSubmitCount` (BUG-171), which checks complete multi-digit job-count
parsing before Condor process expansion.

The files/transfer row also includes `ParslHTTPContentLength` (BUG-172), which checks that a
declared HTTP content length matches the bytes received before a task is admitted.

It also includes `ParslHTTPSeparateStatus` (BUG-217), which applies the response-status safety
boundary to the separate-task `_http_stage_in` path rather than only the in-task wrapper.

The clock/executor coverage also includes `ParslHtexContactTimeoutStarvation` (BUG-218), which
checks that continuous result forwarding cannot suppress the HTEX interchange-contact deadline.

Executor coverage also includes `ParslGlobusComputeResourceSpecType` (BUG-219), which checks
typed admission of per-submit Globus Compute resource specifications before shared SDK state is
mutated.

File-transfer coverage also includes `ParslHTTPSeparateContentLength` (BUG-220), applying the
declared-length safety check to the separate-task HTTP helper as well as the in-task wrapper.

Provider coverage also includes `ParslGridEngineSubmitShape` (BUG-221), which validates the
successful-submit response before admitting a Grid Engine resource.

It also includes `ParslGridEngineEmptySubmit` (BUG-222), which requires an explicit failure when
a successful scheduler command returns no usable job identifier.

Provider coverage also includes `ParslSlurmEmptyJobId` (BUG-223), which rejects a successful
Slurm response whose captured scheduler identifier is empty.

It also includes `ParslTorqueSubmitShape` (BUG-224), which prevents multi-line qsub output from
publishing more than one Torque resource for a single submission.

The foundational gate also runs the compact `ParslTorqueSubmit` success, empty-output, and qsub-
failure configurations. Together they check the provider boundary that turns a scheduler return
code and output into exactly one pending resource, or no resource when submission is unusable.

`ParslTaskVineShutdown` is also in the foundational gate, checking that collector finalization
resolves every outstanding task Future as a manager failure before executor shutdown completes.

`ParslTaskVineResults` is also in the foundational gate, covering valid result deserialization,
task exceptions, corrupt or missing result files, no-result reports, and manager-exit cleanup.

`ParslWorkQueueResults` is also in the foundational gate, covering valid result files, serialized
application exceptions, corrupt output, collector failure cleanup, and terminal-state stability.

The Fixed `ParslCallableRetryTransport` configuration is also in the foundational gate. It connects
per-attempt callable/closure snapshots to serialized ZMQ payloads and rejects stale results from an
older physical attempt; the Current configuration remains a deliberate counterexample.

The Fixed `ParslCallableClosureMemo` configuration is also in the foundational gate. It requires
memoization identity to distinguish callable closure contents; its Current configuration documents
the name/module collision found by the runtime probe.

The three `ParslStageOutFuture` configurations are also in the foundational gate. They cover
separate stage-out, in-task publication, and no-stage output readiness, including dependent-task
admission only after a ready DataFuture.

The three `ParslRsyncStage` configurations are also in the foundational gate, covering stage-in
failure, stage-out failure after application execution, and successful in-task rsync ordering.

`ParslMonitoringDeferred` is also in the foundational gate, checking deferred worker-message replay,
foreign-key ordering, duplicate replacement/discard, and bounded monitoring status insertion.

The Fixed and valid `ParslTimerIntervalValidation` configurations are also in the foundational gate;
the Current configuration remains a counterexample for silent negative-interval clamping.

The basic `ParslCommandClient` reply and timeout configurations are also in the foundational gate,
covering successful REQ/REP completion and permanent bad-client state after response timeout.

Both `ParslJoinNoneResult` configurations are also in the foundational gate, checking successful
single and list joins whose inner Future values are `None` rather than failures or missing values.

The Fixed `ParslJoinReturnEquality` configuration is also in the foundational gate, ensuring
invalid return validation reaches a terminal failure without invoking hostile user equality.

The Fixed `ParslJoinSingleCancellation` configuration is also in the foundational gate, converting
single-inner cancellation into terminal outer join failure instead of leaving the join pending.

`ParslPollerBadState` is also in the foundational gate, checking provider polling status, failure
thresholds, outstanding-task cleanup, and admission/scaling suppression after executor bad state.

The Fixed `ParslApplyDispatchBoundary` configuration is also in the foundational gate, rejecting
malformed apply-message arity before it reaches worker invocation.

The Fixed and valid `ParslPythonTimeoutParameter` configurations are also in the foundational gate;
the Current configuration remains a counterexample for immediate failure from non-positive delays.

The Fixed and success `ParslTimeLimitedOpenTimeout` configurations are also in the foundational gate;
the Current configuration remains a counterexample for opening after the file wait deadline expires.

The Fixed `ParslTimerCloseTimeout` configuration is also in the foundational gate, ensuring a timer
close cannot report completion before its callback thread is quiescent.

The normal and abnormal `ParslMonitoringClose` configurations are also in the foundational gate,
covering workflow-finalization guards and shutdown/drain signaling.

The Fixed `ParslHtexWorkerDrainClock` configuration is also in the foundational gate, checking
monotonic worker-drain deadlines against wall-clock rollback.

The Fixed `ParslResourceMonitorClock` configuration is also in the foundational gate, checking
monotonic remote resource-monitor sampling across wall-clock rollback.

The Fixed and positive `ParslMonitoringBatch` configurations are also in the foundational gate,
checking zero-interval batch collection and available-message consumption.

The Fixed `ParslMonitoringBatchClock` configuration is also in the foundational gate, checking
monotonic batch deadlines across wall-clock rollback.

`ParslProviderKinds` is also in the foundational gate, combining provider submit/status translation,
missing-job handling, cancellation, scale-in, failure/recovery, and resource admission invariants.

`ParslBlockProviderBadState` is also in the foundational gate, checking provider-error cleanup,
terminal Future preservation, and post-failure submission rejection.

`ParslJoinDuplicates` is also in the foundational gate, checking ordered duplicate Future positions,
failure multiplicity, duplicate callback tolerance, and terminal join-handle cleanup.

`ParslJoinErrorRootCause` is also in the foundational gate, checking nested propagated-exception path
annotations and first-leaf root-cause preservation for `JoinError`.

The ZMQ/serialization row also includes `ParslHtexRegistrationShape` (BUG-173), which checks
required HTEX manager-registration fields before manager state is published.

It also includes `ParslHtexRegistrationTypes` (BUG-180), which checks registration version-field
types before string operations and version comparison.

The provider row also includes `ParslGoogleCloudUnknownLocalStatus` (BUG-181), which checks stale
local resource IDs after a valid GCE status response.

The executor row also includes `ParslHtexNegativeScaleInIdle` (BUG-182), which checks negative
idle-only scale-in requests before HTEX block selection.

It also includes `ParslHtexZeroScaleInIdle` (BUG-183), which checks zero-count idle-only requests
as no-ops.

It also includes `ParslHtexScaleInRace` (BUG-184), which checks duplicate provider cancellation
caused by concurrent block selection.

It also includes `ParslFluxLateResultCancelledFuture` (BUG-185), which checks that a late successful
Flux callback cannot write into an already-cancelled user-facing Future.

Flux executor coverage also includes `ParslFluxWorkingDirectory` (BUG-200), which checks that a
relative task path resolves under the configured executor workspace rather than the submitting
process's current directory.

Globus staging coverage also includes `ParslGlobusFailureEvent` (BUG-201), which checks that a
failed transfer with no diagnostic events still produces a terminal transfer failure rather than
an indexing exception.

LSF provider coverage also includes `ParslLsfSubmitJobId` (BUG-202), which checks that malformed
successful-looking scheduler output cannot publish an arbitrary token as a resource identifier.

Torque provider coverage also includes `ParslTorqueCancelUnknown` (BUG-203), which checks that a
successful remote cancellation remains successful when local polling has already removed the job.

PBS Pro provider coverage also includes `ParslPbsproStatusShape` (BUG-204), which checks that a
non-mapping JSON job record cannot abort the status poll.

It also includes `ParslPbsproStatusBatchIsolation` (BUG-264), which checks that a malformed
record cannot prevent independent valid records in the same PBS Pro status batch from being
processed.

Monitoring coverage also includes `ParslMonitoringWorkerTryAtomicity` (BUG-265), which checks
that a worker STATUS write cannot remain committed after the corresponding TRY update fails.

Serialization/HTEX coverage also includes `ParslHtexTaskIngressContinuation`, which refines
BUG-098 from a single malformed envelope to a malformed-then-valid message sequence and checks
that the later valid task remains queueable.
`ParslHtexSerializationFailure` checks that non-`TypeError` serializer failures are normalized
at the HTEX submit boundary instead of escaping as raw implementation exceptions (BUG-268).
`ParslHtexSerializationErrorName` checks that callable instances without `__name__` still produce
an explicit serialization error rather than masking it with `AttributeError` (BUG-272).
The same condition is checked at the concrete Flux submit boundary by
`ParslFluxSerializationErrorName`.
The temporal refinement `ParslHtexResultDecodeContinuation` places a corrupt result before a
valid result in one batch and checks that decode failure cannot strand the later Future (BUG-020).
Provider/executor coverage also includes `ParslPollerExecutorIsolation` (BUG-269), which keeps
one executor's transient status failure from suppressing independent executors in the same poll.
Thread executor coverage also includes `ParslThreadExecutorEmptyResourceSpec` (BUG-271), which
rejects empty non-mapping resource specifications instead of silently accepting them.
Monitoring coverage also includes `ParslMonitoringInternalQueueDrain` (BUG-270), which checks
that shutdown cannot terminate the database loop while an internal pending message remains.

Staging coverage also includes `ParslGlobusTokenSchema` (BUG-266), which checks that an incomplete
but syntactically valid token cache cannot reach service-record indexing as if it were usable.
It also includes `ParslGlobusInitRace` (BUG-267), which checks that concurrent creation of
`~/.parsl` cannot turn successful initialization into `FileExistsError`.

AWS provider coverage also includes `ParslAwsStatusResponseShape` (BUG-205), which checks that a
missing top-level `Reservations` field cannot abort status polling.

Work Queue executor coverage also includes `ParslWorkQueueResourceSpecShape` (BUG-206), which
checks that malformed resource specifications are rejected before task-directory side effects.

TaskVine executor coverage also includes `ParslTaskVineResourceSpecShape` (BUG-207), which checks
that malformed resource specifications are rejected before `.get()` field access.

It also includes `ParslWorkerInitialProbeTimeout` (BUG-186), which checks that a timed-out initial
HTEX connection probe cannot fall through to a blocking receive.

Monitoring coverage also includes `ParslMonitoringExternalQueueEmptyRace` (BUG-187), which checks
that shutdown does not trust a stale `Queue.empty()` observation and strand an external message.

The provider row also includes `ParslTorqueMalformedStatusLine` (BUG-188), which checks malformed
Torque scheduler records before state-column indexing.

It also includes `ParslKubernetesCancelResponse` (BUG-189), which checks that a failed delete
response cannot be published locally as successful cancellation.

The executor/provider row also includes `ParslAwsCancelDuplicates` (BUG-174), which checks that
duplicate AWS cancellation IDs cannot turn a successful remote termination into a local exception,
and `ParslAwsStatusOrdering` (BUG-175), which checks request-order projection for out-of-order EC2
reservations.

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

`ParslNestedJoin` is also in the foundational TLC gate, checking inner-handle completion before
outer observation, ordered nested results, and failure propagation through both join layers.

`ParslSerializationFrameCount` is also in the foundational TLC gate. Its fixed branch rejects
extra apply-message frames before deserialization, while the normal branch preserves the valid
three-frame decode path; the runtime probe documents the current eager-decode behavior.

`ParslSerializationLength` is also in the foundational TLC gate with separate fixed/truncated and
fixed/valid configurations, checking declared-versus-actual payload length before acceptance.

`ParslGlobusTransferFailure` is also in the foundational TLC gate with fixed-empty and success
paths, checking failure publication without indexing an absent diagnostic event.

`ParslStagingProviderDispatch` is also in the foundational TLC gate, checking ordered provider
selection and the distinction between a completed staging result and a Future dependency.

`ParslHeartbeatBoundary` is also in the foundational TLC gate, checking the strict heartbeat
threshold, reset behavior, and cleanup of tasks in flight when a manager expires.

The fixed `ParslHtexHeartbeatVersion` configuration is also in the foundational TLC gate,
composing registration mismatch, heartbeat expiry, fatal-result ordering, and admission blocking.

The busy and idle `ParslHtexWorkerWatchdog` configurations are also in the foundational TLC gate,
checking WorkerLost publication for a failed busy worker and silent replacement of idle capacity.

Fixed `ParslMonitoringThreshold` is also in the foundational TLC gate, checking zero-threshold
monitoring batch consumption and preserving the Current queued-event counterexample.

Fixed `ParslMonitoringVersionedBatch` is also in the foundational TLC gate, checking atomic
transaction rollback and rejection of stale status events below the database version high-water mark.

Fixed `ParslProviderExecutorTimedMonitoring` is also in the foundational TLC gate, composing
provider/manager liveness, retry and stale-result handling, scale-in, and monitoring persistence.

`ParslJoinRetry` is also in the foundational TLC gate, checking logical-Future versus physical-
attempt separation and preventing an outer join from failing on a non-final inner retry.

Fixed `ParslJoinRetryDuplicates` is also in the foundational TLC gate, checking duplicate input
positions remain ordered after a logical inner Future retries.

Fixed `ParslJoinRunningCancellation` is also in the foundational TLC gate, checking cancellation
of a running inner Future produces terminal outer failure with contained callback handling.

Fixed `ParslJoinThreeCancellation` is also in the foundational TLC gate, checking cancellation
inside a three-element join list and callback containment during failure aggregation.

`ParslResultRace` is also in the foundational TLC gate, checking retry-bound attempt correlation,
late-success classification, and logical Future terminal-state consistency.

Fixed and stable `ParslJoinListMutation` are also in the foundational TLC gate, checking that
mutable join-result lists cannot change callback membership after registration.

`ParslJoinThreeList` is also in the foundational TLC gate, checking distinct Future completion,
ordered four-position result reconstruction, and duplicate input preservation.

`ParslHeartbeatProvider` is also in the foundational TLC gate, checking provider status versus
manager heartbeat expiry, capacity admission, and terminal cleanup of in-flight work.

Fixed `ParslFilesystemRadioAtomicity` is also in the foundational TLC gate, checking temporary
pickle writes, atomic publication, reader visibility, and failure isolation.

Fixed `ParslMonitoringStarterConstructionFailure` is also in the foundational TLC gate, checking
that monitoring database construction failures preserve their original exception and cleanup path.

Fixed `ParslMonitoringBatchThree` is also in the foundational TLC gate, checking atomic rollback
of a three-event transaction after a mid-batch write failure.

Fixed `ParslMonitoringUDPPickleIsolation` is also in the foundational TLC gate, checking malformed
authenticated UDP payload isolation and router survival for subsequent valid messages.

Fixed `ParslMonitoringZMQBatchClock` is also in the foundational TLC gate, checking monotonic
receive-batch deadlines across wall-clock rollback.

Fixed `ParslFileTransferMonitoring` is also in the foundational TLC gate, composing chunk
transfer completion, DataFuture readiness, source-version matching, and monitoring persistence.

`ParslTaskTransport` normal and serialization-failure configurations are also in the foundational
TLC gate, connecting object-graph serialization, task-envelope validation, worker dispatch,
result correlation, retry bounds, and stale-result rejection.

`ParslSerializationSnapshot` is also in the foundational TLC gate, checking that mutation of the
original Python object graph cannot change the captured payload or decoded version.

Fixed `ParslDataFutureCancellation` is also in the foundational TLC gate, checking cancellation
propagation from a parent Future to the dependent DataFuture readiness state.

Fixed `ParslDataFutureFalseyException` is also in the foundational TLC gate, checking that
exception presence is propagated even when the exception object has false boolean value.

Fixed `ParslInputDependencyDuplicate` is also in the foundational TLC gate, checking that the
reserved `inputs` Future is registered once before `join_app`-style callback aggregation.

Fixed `ParslRetryHandler` is also in the foundational TLC gate, checking that zero-cost failure
handlers cannot bypass the configured retry bound.

Fixed `ParslTimerReentrantClose` is also in the foundational TLC gate, checking the callback-side
close path without self-joining the timer thread.

`ParslHtexManagerMessage` heartbeat and malformed-message configurations are also in the
foundational TLC gate, checking manager liveness updates, heartbeat replies, and malformed
message isolation.

Fixed `ParslHtexZeroScaleInIdle` is also in the foundational TLC gate, checking that a zero
idle-only scale-in request does not select or cancel any blocks.

`ParslProbeAddresses` timeout, empty-input, and success configurations are also in the
foundational TLC gate, checking HTEX endpoint selection and timeout/rejection behavior.

Fixed `ParslJobStatusOutputReadError` is also in the foundational TLC gate, checking consistent
handling of output and summary read failures.

`ParslJobStatusOutputSummary` threshold, large-file, and missing-file configurations are also in
the foundational TLC gate, checking full output, head/tail truncation, and no-output semantics.

MPI prefix-valid/invalid, fixed resource-spec, and task-context normal/fixed configurations are
also in the foundational TLC gate, checking launcher selection, resource validation, and malformed
task admission.

Fixed `ParslScaleInCancelShape` is also in the foundational TLC gate, checking partial provider
cancellation responses without discarding already-cancelled blocks.

CurveZMQ certificate valid/invalid configurations are also in the foundational TLC gate, checking
private-directory and secret-key guards before loading network credentials.

Fixed `ParslPythonTimeoutCatch` is also in the foundational TLC gate, checking that injected
Python-app walltime timeouts remain terminal rather than being converted into success.

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

HTEX executor coverage also includes `ParslHtexWorkerRestartFailure` (BUG-234), which checks
that a failed worker respawn cannot silently terminate the watchdog while leaving the executor
healthy and affected tasks without a terminal outcome.

LSF provider coverage also includes `ParslLSFMissingJob` (BUG-235), which checks that an empty
successful scheduler response does not falsely complete an active local job.

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

The nested object identity boundary is also backed by `tests/test_python_nested_alias_runtime.py`,
which observes the current independent reconstruction of a closure root and nested argument field.

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
backed by `tests/test_htex_worker_capacity_runtime.py`.  The same runtime bridge now covers the
one-worker fallback when all provider resource hints are absent.
The fallback state machine is `ParslHtexCapacityFallback`.

Monitoring coverage also includes `ParslMonitoringResourceHistory`, an append-only, timestamp-
ordered model for real SQLite `RESOURCE` samples and duplicate primary-key handling, backed by
`tests/test_monitoring_resource_history_runtime.py`.

The monitoring row also includes `ParslMonitoringWorkflowDuration` (BUG-216), which checks that
workflow-finalization duration is represented in the schema and cannot disappear silently during
a bulk update.

Join coverage also includes `ParslJoinThreeList`, which keeps three distinct inner Futures and
four ordered list positions (including a duplicate) separate in the outer result, and
`ParslJoinThreeCancellation`, which exercises a three-element cancelled-inner list, backed by
`tests/test_join_three_list_runtime.py` and `tests/test_join_list_cancellation_runtime.py`.

`ParslJoinEndToEnd` is promoted into the foundational TLC gate as the compact baseline for
logical-Future versus physical-attempt separation, retry/cancellation/failure aggregation, and
ordered outer-join result publication.

The current `join_app` source audit maps `DataFlowKernel.handle_join_update` to the join models
for ordered list membership, duplicate callbacks, callback locking, cancellation, failure
aggregation, mutable-list snapshots, and nested joins. The remaining coarse boundary is Python
exception/object identity and unconstrained thread scheduling, not an unexamined join state.

Provider coverage also includes `ParslGoogleCloudStatusRemoteFailure` (BUG-252), which models
per-job Google Compute Engine status failures as isolated UNKNOWN observations so a transient
not-found/error response cannot abort later healthy jobs in the same polling batch. Its current
configuration produces a `StatusBatchSafety` counterexample, while the fixed configuration
passes; the runtime probe is `tests/test_googlecloud_status_remote_failure_runtime.py`.

AWS provider coverage also includes `ParslAwsStatusReservationShape` (BUG-253) and
`ParslAwsInstanceStateShape` (BUG-280), which check
that a malformed nested `Reservations` entry cannot abort processing of later healthy entries.
The current configuration violates `NestedShapeSafety`; the fixed configuration passes, with
the runtime probe in `tests/test_aws_status_reservation_shape_runtime.py`.

Azure provider coverage also includes `ParslAzureStatusOrdering` (BUG-254), checking that a
reordered status list cannot turn a running VM into a pending observation. The current model
violates `RunningStatusSafety`, while the semantic-selection fixed model passes; its runtime
probe is `tests/test_azure_status_ordering_runtime.py`.

Worker lifecycle timing also includes `ParslHtexWorkerDrainClock` (BUG-256), which checks that
an elapsed worker drain deadline remains effective after a wall-clock rollback. The current
configuration violates `DrainDeadlineSafety`; the fixed model passes with
`tests/test_htex_worker_drain_clock_runtime.py` as the runtime probe.

Work Queue result handling also includes `ParslWorkQueueMalformedReport` (BUG-257), which
models a malformed collector report preceding a valid report. The current configuration
violates `MalformedReportSafety`; the fixed model passes with
`tests/test_workqueue_malformed_report_runtime.py` as the runtime probe.

TaskVine result handling also includes `ParslTaskVineMalformedReport` (BUG-258), which models
the same malformed-report boundary in the TaskVine collector independently. The current
configuration violates `MalformedReportSafety`; the fixed model passes with
`tests/test_taskvine_malformed_report_runtime.py` as the runtime probe.

HTEX result handling also includes `ParslHtexUnknownResultType` (BUG-255), which models an
unknown decoded result-frame type followed by a valid frame. The current configuration violates
`UnknownTypeSafety`; the fixed model passes and the runtime probe is
`tests/test_htex_unknown_result_type_runtime.py`.

Core dataflow coverage also includes `ParslInputDependencyDuplicate` (BUG-259), which models
the reserved `inputs` kwarg being traversed twice by `_gather_all_deps`. The current
configuration violates `NoDuplicateDependency`; the fixed model passes with
`tests/test_input_dependency_duplicate_runtime.py` as the runtime probe.

`ParslDependencyIdentityDedup` refines BUG-259 to the cross-position case: one Future appears in
both a normal kwarg and `inputs`. The current model registers it three times, while the fixed
model records the Future identity once before callback registration.

Monitoring lifecycle coverage also includes `ParslMonitoringHubCloseBeforeStart` (BUG-260), which
models cleanup before `MonitoringHub.start()` initializes its active flag. The current branch
violates `NoCloseCrash`; the fixed branch makes an unstarted close a no-op.

`ParslMonitoringHubStartFailureCleanup` (BUG-261) covers the complementary partial-start path:
the current branch leaves the hub active after child-process startup fails, while the fixed branch
rolls back the allocated lifecycle state.

`ParslMonitoringHubRepeatedStart` (BUG-262) checks single ownership across repeated monitoring
hub starts. The current branch creates a second process/queue and loses the first handles; the
fixed branch rejects the duplicate start without allocating resources.
