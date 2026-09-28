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
`ParslSerializerRegistry.tla` models the concrete code/data serializer registries and their
code-first dispatch order. An identifier collision is a current-path counterexample and a fixed
path rejection; the runtime probe confirms the current facade behavior.
`ParslExecutorProviderLifecycle.tla` connects provider allocation and terminal cleanup to manager
registration, executor drain, worker-slot admission, and scale-in. Its fixed branch enforces the
provider `MIN_BLOCKS` floor.
`ParslZMQSerializationEndToEnd.tla` combines concrete serializer headers and multipart ZMQ
progress with worker-attempt correlation. Its current branch exposes wrong-attempt result
resolution; the fixed branch classifies those messages as stale.
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
`ParslHtexResultQueue.tla` probes the concrete HTEX result queue worker, including valid and
exception result decoding, malformed/duplicate messages, interchange failure, and Future orphaning
when the current pop-before-validation path exits the worker.
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
`ParslExecutorShutdown.tla` refines concrete shutdown behavior: ThreadPool waits for accepted
work, WorkQueue's collector fails tasks left behind during process shutdown, and HTEX closes its
interchange before in-flight cleanup. It also checks that shutdown rejects new submissions.
`ParslWorkQueueResults.tla` refines WorkQueue's collector result protocol: valid result files,
deserialization failures, app exceptions, no-result reports, and final cleanup of outstanding
tasks when the collector exits.
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
`ParslTaskVineResults.tla` refines TaskVine's manager report and collector protocol, including
result-file failure mapping and cleanup of all outstanding Futures after manager failure.
`ParslTaskVineDuplicateReport.tla` adds the stale-report interleaving to that collector. It
captures the current duplicate-ID `KeyError`, the resulting collector exit and unrelated-future
cleanup, and the candidate idempotent guard.
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
`tests/test_kubernetes_cancel_runtime.py` drives pod deletion with a fake API, distinguishing
exception propagation from a returned error object that the current wrapper ignores. The
`ParslKubernetesCancel.tla` fixed model preserves `RUNNING` for that returned-error case.
`tests/test_aws_status_runtime.py` drives `AWSProvider.status` with a fake EC2 client, checking
missing-instance behavior and normal instance-state translation.
`tests/test_aws_submit_runtime.py` drives `AWSProvider.submit` with a fake instance launcher,
checking successful registration, failed launch handling, unknown-state fallback, and the empty
launch-response unpacking path modeled by `ParslAWSProviderSubmit.tla`.
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
`ParslLocalProviderStatusScope.tla` models the current `status(job_ids)` implementation's loop
over all resources. Its current configuration exposes an unrelated missing `.ec` file aborting a
valid query, while the fixed configuration limits observation to requested IDs.
`ParslGridEngineStatus.tla` models the Grid Engine malformed-qstat boundary. Its current
configuration reproduces the short-line crash; fixed and valid-output configurations pass.
`ParslGoogleCloudStatus.tla` models direct GCE status-table lookup: the current unknown-status
configuration produces a depth-2 `KeyError`-style crash, while tolerant and known-status paths
pass.
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
'test_*runtime.py'`; the current suite has 232 passing tests and intentionally uses local/fake
providers instead of external scheduler or cloud credentials.

The model is intentionally a bounded protocol abstraction. A passing TLC run means that the
specified finite abstraction satisfies the listed properties; it does not prove that every
implementation detail of Parsl is correct.
